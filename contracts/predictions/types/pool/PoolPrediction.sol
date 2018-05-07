pragma solidity ^0.4.23;
import "../../../oracles/types/MultipleOutcomeOracle.sol";
import "../../../token/IERC20Token.sol";
import "./PoolPredictionPrizeDistribution.sol";
import "../../management/PredictionMetaData.sol";
import "../../prizeCalculations/IPrizeCalculation.sol";
import "../../methods/IPredictionMethods.sol";


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
contract PoolPrediction is PoolPredictionPrizeDistribution, IPredictionMethods {
   
    /*
     *  Events
     */
    event TokensPlacedOnOutcome(address indexed _owner, bytes32 indexed _outcome, uint _tokenAmount);
    event UserRefunded(address indexed _owner, bytes32 indexed _outcome, uint _tokenAmount);
    event OutcomeAdded(bytes32 indexed _id);

    /**
        @dev Check if the prediction has this outcome id

        @param _outcome Outcome to check
    */
    modifier outcomeValid(bytes32 _outcome) {
        require(doesOutcomeExist(_outcome));
        _;
    }
    
    /*
     *  Enum and Structs
     */

    // Holds user's tokens amount 
    struct UserTokens {
        uint    tokens;
        bool    hasWithdrawn;
    }

    // Holds outcome's tokens amount
    struct OutcomeProperties {
        uint    tokens;
        bool    doesExist;
    }

    /*
     *  Members
     */
    IERC20Token                                                 public stox;                // Stox ERC20 token
    bytes32                                                     public winningOutcome;
    bytes32[]                                                   public outcomes;            // Allows monitoring general existence of outcomes
    mapping(bytes32 => OutcomeProperties)                       public outcomesProperties;      // Per outcome data
    uint                                                        public tokenPool;           // Total tokens used to buy units in this prediction

    
    // Mapping to see all the total tokens bought per outcome, per user (user address -> outcome -> uint)
    mapping(address => mapping(bytes32 => uint)) public ownerAccumulatedTokensPerOutcome;

    // Mapping to see all tokens placed by a user (user address -> UserTokens)
    mapping(address => UserTokens) public ownerTotalTokenPlacements;

    /*
        @dev constructor

        @param _owner                       Prediction owner / operator
        @param _oracle                      The oracle provides the winning outcome for the prediction
        @param _predictionEndTimeSeconds    Prediction end time
        @param _tokensPlacementEndTimeSeconds        outcome buying end time
        @param _name                        Prediction name
        @param _stox                        Stox ERC20 token address
        @param _calculationMethod           Method of calculating prizes
    */
    constructor(address _owner,
            address _oracle,
            uint _predictionEndTimeSeconds,
            uint _tokensPlacementEndTimeSeconds,
            string _name,
            IERC20Token _stox,
            IPrizeCalculation _prizeCalculation)
            public 
            validAddress(_owner)
            validAddress(_stox)
            Ownable(_owner)
            PredictionTiming(_predictionEndTimeSeconds, _tokensPlacementEndTimeSeconds)
            PredictionMetaData(_name, _oracle, _prizeCalculation)
            {

        stox = _stox;
    }

    /*
        @dev Allow the prediction owner to add a new outcome to the prediction

        @param _id   Outcome value
    */
    function addOutcome(bytes32 _id) public ownerOnly notEmptyBytes(_id) statusIs(Status.Initializing) {
        outcomes.push(_id);
        outcomesProperties[_id].doesExist = true;
        
        emit OutcomeAdded(_id);
    }

    /*
        @dev Allow the prediction owner to publish the prediction - Users can now buy unit on the various outcomes.
    */
    function publish() public ownerOnly {
        require (outcomes.length > 1);
        PredictionStatus.publish();
    }
        
    /*
        @dev Allow a user to place tokens on an outcome. Note that users can make multiple placements on multiple outcomes.
        Before calling placeTokensFor the user should first call the approve(thisPredictionAddress, tokenAmount) on the
        stox token (or any other ERC20 token).

        @param _owner       The owner
        @param _tokenAmount The amount of tokens invested in this outcome
        @param _outcome     The outcome the user predicts
    */
    function placeTokensFor(address _owner, uint _tokenAmount, bytes32 _outcome)
            public
            statusIs(Status.Published)
            validAddress(_owner)
            greaterThanZero(_tokenAmount)
            outcomeValid(_outcome) {
        
        require(tokensPlacementEndTimeSeconds > now);

        tokenPool = safeAdd(tokenPool, _tokenAmount);
        outcomesProperties[_outcome].tokens = safeAdd(outcomesProperties[_outcome].tokens, _tokenAmount);
        ownerTotalTokenPlacements[_owner].tokens = safeAdd(ownerTotalTokenPlacements[_owner].tokens, _tokenAmount);

        ownerAccumulatedTokensPerOutcome[_owner][_outcome] =
            safeAdd(ownerAccumulatedTokensPerOutcome[_owner][_outcome], _tokenAmount); 
    
        assert(stox.transferFrom(_owner, this, _tokenAmount));
        
        emit TokensPlacedOnOutcome(_owner, _outcome, _tokenAmount);
    }


    /*
        @dev Allow a user to place tokens on a specific outcome. Note that users can make multiple placements on multiple outcomes.
        Before calling placeTokens the user should first call the approve(thisPredictionAddress, tokenAmount) on the
        stox token (or any other ERC20 token).

        @param _tokenAmount     The amount of tokens invested in this outcome
        @param _outcome         The outcome the user predicts.
    */
    function placeTokens(uint _tokenAmount, bytes32 _outcome) external  {
        placeTokensFor(msg.sender, _tokenAmount, _outcome);
    }


    /*
        @dev Allow the prediction owner to resolve the prediction.
        Before calling resolve() the oracle owner should first set the prediction outcome by calling setOutcome(thisPredictionAddress, winningOutcomeId)
        in the Oracle contract.
    */
    function resolve() public ownerOnly {
        require(doesOutcomeExist((MultipleOutcomeOracle(oracleAddress)).getOutcome(this)) &&
            (tokensPlacementEndTimeSeconds < now));
        
        winningOutcome = (MultipleOutcomeOracle(oracleAddress)).getOutcome(this);

        PredictionStatus.resolve(oracleAddress, winningOutcome);
    }
    
    /*
        @dev After the prediction is resolved the user can withdraw tokens from his winning outcomes
    */
    function withdrawPrize() public statusIs(Status.Resolved) {
        require((ownerTotalTokenPlacements[msg.sender].tokens > 0) &&
                (!ownerTotalTokenPlacements[msg.sender].hasWithdrawn));

        distributePrizeToUser(stox, 
                              ownerTotalTokenPlacements[msg.sender].tokens,
                              ownerAccumulatedTokensPerOutcome[msg.sender][winningOutcome], 
                              outcomesProperties[winningOutcome].tokens, 
                              tokenPool);

        ownerTotalTokenPlacements[msg.sender].hasWithdrawn = true;
    }
    
    /*
        @dev Returns the amount of tokens a user can withdraw from his winning outcome after the prediction is resolved

        @param _owner   Placements owner

        @return         Token amount
    */ 
    function calculateUserWithdrawAmount(address _owner) external statusIs(Status.Resolved) constant returns (uint) {
        
        return (prizeCalculation.calculatePrizeAmount(ownerTotalTokenPlacements[_owner].tokens, 
                                     ownerAccumulatedTokensPerOutcome[_owner][winningOutcome], 
                                     outcomesProperties[winningOutcome].tokens, 
                                     tokenPool));
    }
        
    /*
        @dev Allow to prediction owner / operator to cancel the user's placements and refund the tokens.

        @param _owner       Placements owner
        @param _outcome     Outcome to refund
    */
    function refundUser(address _owner, bytes32 _outcome) public ownerOnly {
        require (status != Status.Resolved);
        
        performRefund(_owner, _outcome);
    }
   
    /*
        @dev Allow the user to cancel his placements and refund the tokens he invested.
        Can be called only after the prediction is canceled.

        @param _outcomeId   Outcome to refund
    */
    function getRefund(bytes32 _outcome) public statusIs(Status.Canceled) {
               
        performRefund(msg.sender, _outcome);
    }

    /*
        @dev Refund a specific user's token placements and cancel them

        @param _owner       Placements owner
        @param _outcomeId   Outcome to refund
    */
    function performRefund(address _owner, bytes32 _outcome) private {
        require((tokenPool > 0) &&
                hasTokenPlacements(_owner, _outcome));

        uint refundAmount = ownerAccumulatedTokensPerOutcome[_owner][_outcome];

        if (refundAmount > 0) {
            tokenPool = safeSub(tokenPool, refundAmount);
            ownerTotalTokenPlacements[_owner].tokens = safeSub(ownerTotalTokenPlacements[_owner].tokens, 
                                                                refundAmount);
            ownerAccumulatedTokensPerOutcome[_owner][_outcome] = 0;
                                                    
            assert(stox.transfer(_owner, refundAmount)); // Refund the user
        }

        emit UserRefunded(_owner, _outcome, refundAmount);
    }
           
    /*
        @dev Returns true if the prediction contains a specific outcome id

        @param _outcomeId   Outcome id

        @return             true if the outcome exists
    */
    function doesOutcomeExist(bytes32 _outcome) private view returns (bool) {
        return (outcomesProperties[_outcome].doesExist);
    }

    /*
        @dev Returns true if the user bought units of a specific outcome

        @param _owner       Placements owner
        @param _outcome     Outcome id

        @return             true if the user bought units on a specific outcome
    */
    function hasTokenPlacements(address _owner, bytes32 _outcome) private view returns(bool) {
        return (ownerAccumulatedTokensPerOutcome[_owner][_outcome] > 0);
    }

    /*
        @dev Returns number of outcomes

        @return   number of outcomes
    */
    function getNumberOfOutcomes() external constant returns (uint) {
        return outcomes.length;
    }
}


