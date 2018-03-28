pragma solidity ^0.4.18;
import "../../../oracles/types/MultipleOutcomeOracle.sol";
import "../../../token/IERC20Token.sol";
import "./PoolPredictionPrizeDistribution.sol";
import "../../management/PredictionMetaData.sol";


/**
    @title Pool prediction contract - Pool predictions distributes tokens between all winners according to
    the distribution (calculation) method. The prediction winning outcome is decided by the oracle.

    An example of a relative pool prediction
    ----------------------------------------

    A prediction has 3 different outcomes:
    1. Outcome1
    2. Outcome2
    3. Outcome3

    User A placed 100 tokens on Outcome1
    User B placed 300 tokens on Outcome1
    User C placed 100 tokens on Outcome2
    User D placed 100 tokens on Outcome3

    Total token pool: 600

    After the prediction ends, the oracle decides that the winning outcome is Outcome1

    Users can now withdraw from their units the following token amount:
    User A -> 150 tokens (100 / (100 + 300) * 600)
    User B -> 450 tokens (300 / (100 + 300) * 600)
    User C -> 0 tokens
    User D -> 0 tokens
 */
contract PoolPrediction is PoolPredictionPrizeDistribution {

    
    /*
     *  Events
     */
    event TokensPlacedOnOutcome(address indexed _owner, uint indexed _outcomeId, uint _tokenAmount);
    event UserRefunded(address indexed _owner, uint _outcomeId, uint _tokenAmount);
    event OutcomeAdded(uint indexed _outcomeId, string _name);

    /**
        @dev Check if the prediction has this outcome id

        @param _outcomeId Outcome to check
    */
    modifier outcomeValid(uint _outcomeId) {
        require(doesOutcomeExist(_outcomeId));
        _;
    }

    struct Outcome {
        uint    id;         // Id will start at 1, and increase by 1 for every new outcome
        string  name;           
        uint    tokens;     // Total tokens used to buy units for this outcome
    }

    struct OutcomeTokens {
        uint    tokens;
        bool    isWithdrawn;
    }

    /*
     *  Members
     */
    IERC20Token                                                 public stox;                // Stox ERC20 token
    uint                                                        public winningOutcomeId;
    PoolPredictionCalculationMethods.PoolCalculationMethod      public withdrawCalculationMethod;
    Outcome[]                                                   public outcomes;
    uint                                                        public tokenPool;           // Total tokens used to buy units in this prediction

    
    // Mapping to see all the total tokens bought per outcome, per user (user address -> outcome id -> OutcomeTokens)
    mapping(address => mapping(uint => OutcomeTokens)) public ownerAccumulatedTokensPerOutcome;

    mapping(address => uint) public ownerTotalTokenPlacements;

    /*
        @dev constructor

        @param _owner                       Prediction owner / operator
        @param _oracle                      The oracle provides the winning outcome for the prediction
        @param _predictionEndTimeSeconds    Prediction end time
        @param _buyingEndTimeSeconds        outcome buying end time
        @param _name                        Prediction name
        @param _stox                        Stox ERC20 token address
        @param _calculationMethod           Method of calculating prizes
    */
    function PoolPrediction(address _owner,
            address _oracle,
            uint _predictionEndTimeSeconds,
            uint _buyingEndTimeSeconds,
            string _name,
            IERC20Token _stox,
            PoolPredictionCalculationMethods.PoolCalculationMethod _calculationMethod)
            public 
            validAddress(_oracle)
            validAddress(_owner)
            validAddress(_stox)
            greaterThanZero(_predictionEndTimeSeconds)
            greaterThanZero(_buyingEndTimeSeconds)
            notEmpty(_name)
            Ownable(_owner)
            PoolPredictionPrizeDistribution(_predictionEndTimeSeconds, _buyingEndTimeSeconds)
            PredictionMetaData(_name, _oracle)
            {

        stox = _stox;
        withdrawCalculationMethod = _calculationMethod;
    }

    /*
        @dev Allow the prediction owner to change add a new outcome to the prediction

        @param _name Outcome name
    */
    function addOutcome(string _name) public ownerOnly notEmpty(_name) statusIs(Status.Initializing) {
        uint outcomeId = safeAdd(outcomes.length, 1);
        outcomes.push(Outcome(outcomeId, _name, 0));

        OutcomeAdded(outcomeId, _name);
    }

    /*
        @dev Allow the prediction owner to publish the prediction - Users can now buy unit on the various outcomes.
    */
    function publish() public ownerOnly {
        require (outcomes.length > 1);

        PredictionStatus.publish();
    }
    
    
    /*
        @dev Allow any user to place tokens on an outcome. Note that users can make multiple placements, on multiple outcomes.
        Before calling placeTokensFor the user should first call the approve(thisPredictionAddress, tokenAmount) on the
        stox token (or any other ERC20 token).

        @param _owner       The owner
        @param _tokenAmount The amount of tokens invested in this outcome
        @param _outcomeId   The outcome the user predicts
    */
    function placeTokensFor(address _owner, uint _tokenAmount, uint _outcomeId)
            public
            statusIs(Status.Published)
            validAddress(_owner)
            greaterThanZero(_tokenAmount)
            outcomeValid(_outcomeId) {
        
        require(unitBuyingEndTimeSeconds > now);

        tokenPool = safeAdd(tokenPool, _tokenAmount);
        outcomes[_outcomeId - 1].tokens = safeAdd(outcomes[_outcomeId - 1].tokens, _tokenAmount);
        ownerTotalTokenPlacements[_owner] = safeAdd(ownerTotalTokenPlacements[_owner], _tokenAmount);

        if (ownerAccumulatedTokensPerOutcome[_owner][_outcomeId].tokens > 0) {
            ownerAccumulatedTokensPerOutcome[_owner][_outcomeId].tokens =
             safeAdd(ownerAccumulatedTokensPerOutcome[_owner][_outcomeId].tokens, _tokenAmount); 
        } else {
            ownerAccumulatedTokensPerOutcome[_owner][_outcomeId] = OutcomeTokens(_tokenAmount, false);
        }
        
        assert(stox.transferFrom(_owner, this, _tokenAmount));
        
        TokensPlacedOnOutcome(_owner, _outcomeId, _tokenAmount);
    }


    /*
        @dev Allow any user to place tokens on a specific outcome.
        Before calling placeTokens the user should first call the approve(thisPredictionAddress, tokenAmount) on the
        stox token (or any other ERC20 token).

        @param _tokenAmount The amount of tokens invested in this outcome
        @param _outcomeId   The outcome the user predicts.
    */
    function placeTokens(uint _tokenAmount, uint _outcomeId) external  {
        placeTokensFor(msg.sender, _tokenAmount, _outcomeId);
    }


    /*
        @dev Allow the prediction owner to resolve the prediction.
        Before calling resolve() the oracle owner should first set the prediction outcome by calling setOutcome(thisPredictionAddress, winningOutcomeId)
        in the Oracle contract.
    */
    function resolve() public ownerOnly {
        require(doesOutcomeExist((MultipleOutcomeOracle(oracleAddress)).getOutcome(this)) &&
            (unitBuyingEndTimeSeconds < now));

        winningOutcomeId = (MultipleOutcomeOracle(oracleAddress)).getOutcome(this);

        assert(outcomes[winningOutcomeId - 1].tokens > 0);
        
        //int winningOutcomeIdtoInt = int(winningOutcomeId);
        //PredictionStatus.resolve(oracleAddress, int(winningOutcomeId));
        PredictionStatus.resolve(oracleAddress, winningOutcomeId);
    }
    
    /*
        @dev After the prediction is resolved the user can withdraw tokens from his winning outcomes
        
     */
    function withdrawPrize() public statusIs(Status.Resolved) {
        require(ownerTotalTokenPlacements[msg.sender] > 0);

        uint winningOutcomeTokens = outcomes[winningOutcomeId - 1].tokens;
        
        distributePrizeToUser(stox, 
                                withdrawCalculationMethod, 
                                ownerTotalTokenPlacements[msg.sender],
                                ownerAccumulatedTokensPerOutcome[msg.sender][winningOutcomeId].tokens, 
                                winningOutcomeTokens, 
                                tokenPool);

        ownerAccumulatedTokensPerOutcome[msg.sender][winningOutcomeId].isWithdrawn = true;
    }

    
    /*
        @dev Returns the amount of tokens a user can withdraw from his winning outcome after the prediction is resolved

        @param _owner   Placements owner

        @return         Token amount
    */ 
    function calculateUserWithdrawAmount(address _owner) external statusIs(Status.Resolved) constant returns (uint) {
        
        uint winningOutcomeTokens = outcomes[winningOutcomeId - 1].tokens;
        return (calculateWithdrawalAmount(withdrawCalculationMethod, 
                                            ownerTotalTokenPlacements[_owner], 
                                            ownerAccumulatedTokensPerOutcome[_owner][winningOutcomeId].tokens, 
                                            winningOutcomeTokens, 
                                            tokenPool));
    }

        
    /*
        @dev Allow to prediction owner / operator to cancel the user's placements and refund the tokens.

        @param _owner       Placements owner
        @param _outcomeId   Outcome to refund
    */
    function refundUser(address _owner, uint _outcomeId) public ownerOnly {
        require ((status != Status.Resolved) &&
                (ownerAccumulatedTokensPerOutcome[_owner][_outcomeId].tokens > 0));
        
        performRefund(_owner, _outcomeId);
        
    }

   
    /*
        @dev Allow the user to cancel his placements and refund the tokens he invested.
        Can be called only after the prediction is canceled.

        @param _outcomeId   Outcome to refund
    */
    function getRefund(uint _outcomeId) public statusIs(Status.Canceled) {
        require(ownerAccumulatedTokensPerOutcome[msg.sender][_outcomeId].tokens > 0);
        
        performRefund(msg.sender, _outcomeId);
    }

    /*
        @dev Refund a specific user's token placements and cancel them

        @param _owner       Placements owner
        @param _outcomeId   Outcome to refund
    */

    function performRefund(address _owner, uint _outcomeId) private {
        require((tokenPool > 0) &&
                hasTokenPlacements(_owner, _outcomeId));

        uint refundAmount = ownerAccumulatedTokensPerOutcome[_owner][_outcomeId].tokens;

        if (refundAmount > 0) {
            tokenPool = safeSub(tokenPool, refundAmount);
            ownerTotalTokenPlacements[_owner] = safeSub(ownerTotalTokenPlacements[_owner], refundAmount);
            ownerAccumulatedTokensPerOutcome[_owner][_outcomeId].isWithdrawn = true;
            stox.transfer(_owner, refundAmount); // Refund the user
        }

        UserRefunded(_owner, _outcomeId, refundAmount);
    }
    
    
    /*
        @dev Returns the outcome name of a specific outcome id

        @param _outcomeId   Outcome id

        @return             Outcome name
    */
    function getOutcome(uint _outcomeId) public view returns (string) {
        require(doesOutcomeExist(_outcomeId));

        return (outcomes[_outcomeId - 1].name);
    }

    /*
        @dev Returns true if the prediction contains a specific outcome id

        @param _outcomeId   Outcome id

        @return             true if the outcome exists
    */
    function doesOutcomeExist(uint _outcomeId) private view returns (bool) {
        return ((_outcomeId > 0) && (_outcomeId <= outcomes.length));
    }

    /*
        @dev Returns true if the user's units of an outcome are all withdrawn

        @param _owner       Placements owner
        @param _outcomeId   Outcome id

        @return             true if the user's units  on an outcome are all withdrawn
    */
    function areTokenPlacementsWithdrawn(address _owner, uint _outcomeId) private view returns(bool) {
        return (ownerAccumulatedTokensPerOutcome[_owner][_outcomeId].isWithdrawn);
    }

    /*
        @dev Returns true if the user bought units of a specific outcome

        @param _owner       Placements owner
        @param _outcomeId   Outcome id

        @return             true if the user bought units on a specific outcome
    */
    function hasTokenPlacements(address _owner, uint _outcomeId) private view returns(bool) {
        return (ownerAccumulatedTokensPerOutcome[_owner][_outcomeId].tokens > 0);
    }
}

