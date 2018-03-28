pragma solidity ^0.4.18;
import "../../../oracles/types/ScalarOracle.sol";
import "../../../token/IERC20Token.sol";
import "./ScalarPredictionPrizeDistribution.sol";
import "../../management/PredictionMetaData.sol";

contract ScalarPrediction is ScalarPredictionPrizeDistribution {

    
    /*
     *  Events
     */
    event TokensPlacedOnOutcome(address indexed _owner, uint indexed _outcome, uint _tokenAmount);
    event UserRefunded(address indexed _owner, uint _outcome, uint _tokenAmount);

    struct OutcomeTokens {
        uint    tokens;
        bool    isWithdrawn;
    }

    /*
     *  Members
     */
    IERC20Token                                                   public stox;                // Stox ERC20 token
    uint                                                          public winningOutcome;
    ScalarPredictionCalculationMethods.ScalarCalculationMethod    public withdrawCalculationMethod;
    uint                                                          public tokenPool;           // Total tokens used to buy units in this prediction

    // Mapping to see all the total tokens bought per outcome, per user (user address -> outcome -> OutcomeTokens)
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
    function ScalarPrediction(address _owner,
            address _oracle,
            uint _predictionEndTimeSeconds,
            uint _buyingEndTimeSeconds,
            string _name,
            IERC20Token _stox,
            ScalarPredictionCalculationMethods.ScalarCalculationMethod _calculationMethod)
            public 
            validAddress(_oracle)
            validAddress(_owner)
            validAddress(_stox)
            greaterThanZero(_predictionEndTimeSeconds)
            greaterThanZero(_buyingEndTimeSeconds)
            notEmpty(_name)
            Ownable(_owner)
            ScalarPredictionPrizeDistribution(_predictionEndTimeSeconds, _buyingEndTimeSeconds)
            PredictionMetaData(_name, _oracle)
            {

        stox = _stox;
        withdrawCalculationMethod = _calculationMethod;
    }

    /*
        @dev Allow any user to place tokens on his/her chosen outcome value. Note that users can make multiple placements, 
        on multiple outcomes.
        Before calling placeTokensFor the user should first call the approve(thisPredictionAddress, tokenAmount) on the
        stox token (or any other ERC20 token).

        @param _owner       The owner
        @param _tokenAmount The amount of tokens invested in this outcome
        @param _outcomeId   The outcome the user predicts.
    */
    function placeTokensFor(address _owner, uint _tokenAmount, uint _outcome)
            public
            statusIs(Status.Published)
            validAddress(_owner)
            greaterThanZero(_tokenAmount)
            {
        
        require(unitBuyingEndTimeSeconds > now);

        tokenPool = safeAdd(tokenPool, _tokenAmount);
        ownerTotalTokenPlacements[_owner] = safeAdd(ownerTotalTokenPlacements[_owner], _tokenAmount);

        if (ownerAccumulatedTokensPerOutcome[_owner][_outcome].tokens > 0) {
            ownerAccumulatedTokensPerOutcome[_owner][_outcome].tokens =
             safeAdd(ownerAccumulatedTokensPerOutcome[_owner][_outcome].tokens, _tokenAmount); 
        } else {
            ownerAccumulatedTokensPerOutcome[_owner][_outcome] = OutcomeTokens(_tokenAmount, false);
        }
        
        assert(stox.transferFrom(_owner, this, _tokenAmount));
        
        TokensPlacedOnOutcome(_owner, _outcome, _tokenAmount);
    }

    /*
        @dev Allow any user to place tokens on a specific outcome.
        Before calling placeTokens the user should first call the approve(thisPredictionAddress, tokenAmount) on the
        stox token (or any other ERC20 token).

        @param _tokenAmount The amount of tokens invested on this outcome
        @param _outcomeId   The outcome the user predicts.
    */
    function placeTokens(uint _tokenAmount, uint _outcome) external  {
        placeTokensFor(msg.sender, _tokenAmount, _outcome);
    }

    /*
        @dev Allow the prediction owner to resolve the prediction.
        Before calling resolve() the oracle owner should first set the prediction outcome by calling setOutcome(thisPredictionAddress, winningOutcomeId)
        in the Oracle contract.
    */
    function resolve() public ownerOnly {
        require(unitBuyingEndTimeSeconds < now);

        winningOutcome = (ScalarOracle(oracleAddress)).getOutcome(this);

        //assert(outcomes[winningOutcomeId - 1].tokens > 0);

        PredictionStatus.resolve(oracleAddress, winningOutcome);
    }

    /*
        @dev After the prediction is resolved the user can withdraw tokens from his winning outcomes
        
     */
    function withdrawPrize() public statusIs(Status.Resolved) {
        require(ownerTotalTokenPlacements[msg.sender] > 0);

        if (ownerAccumulatedTokensPerOutcome[msg.sender][winningOutcome].tokens > 0) {
            
            distributePrizeToUser(stox, 
                                    withdrawCalculationMethod, 
                                    ownerTotalTokenPlacements[msg.sender],
                                    ownerAccumulatedTokensPerOutcome[msg.sender][winningOutcome].tokens, 
                                    tokenPool);

        
            ownerAccumulatedTokensPerOutcome[msg.sender][winningOutcome].isWithdrawn = true;
        }
    }

    /*
        @dev Returns the amount of tokens a user can withdraw from his winning outcome after the prediction is resolved

        @param _owner   Placements owner

        @return         Token amount
    */ 
    function calculateUserWithdrawAmount(address _owner) external statusIs(Status.Resolved) constant returns (uint) {
        
        return (calculateWithdrawalAmount(withdrawCalculationMethod, 
                                            ownerTotalTokenPlacements[_owner], 
                                            ownerAccumulatedTokensPerOutcome[_owner][winningOutcome].tokens, 
                                            tokenPool));
    }

    /*
        @dev Allow to prediction owner / operator to cancel the user's placements and refund the tokens.

        @param _owner       Placements owner
        @param _outcomeId   Outcome to refund
    */
    function refundUser(address _owner, uint _outcome) public ownerOnly {
        require ((status != Status.Resolved) &&
                (ownerAccumulatedTokensPerOutcome[_owner][_outcome].tokens > 0));
        
        performRefund(_owner, _outcome);
        
    }

    /*
        @dev Allow the user to cancel his placements and refund the tokens he invested.
        Can be called only after the prediction is canceled.

        @param _outcomeId   Outcome to refund
    */
    function getRefund(uint _outcome) public statusIs(Status.Canceled) {
        require(ownerAccumulatedTokensPerOutcome[msg.sender][_outcome].tokens > 0);
        
        performRefund(msg.sender, _outcome);
    }

    /*
        @dev Refund a specific user's token placements and cancel them

        @param _owner       Placements owner
        @param _outcomeId   Outcome to refund
    */

    function performRefund(address _owner, uint _outcome) private {
        require((tokenPool > 0) &&
                hasTokenPlacements(_owner, _outcome));

        uint refundAmount = ownerAccumulatedTokensPerOutcome[_owner][_outcome].tokens;

        if (refundAmount > 0) {
            tokenPool = safeSub(tokenPool, refundAmount);
            ownerTotalTokenPlacements[_owner] = safeSub(ownerTotalTokenPlacements[_owner], refundAmount);
            ownerAccumulatedTokensPerOutcome[_owner][_outcome].isWithdrawn = true;
            stox.transfer(_owner, refundAmount); // Refund the user
        }

        UserRefunded(_owner, _outcome, refundAmount);
    }

    /*
        @dev Returns true if the user's units of an outcome are all withdrawn

        @param _owner       Placements owner
        @param _outcomeId   Outcome id

        @return             true if the user's units  on an outcome are all withdrawn
    */
    function areTokenPlacementsWithdrawn(address _owner, uint _outcome) private view returns(bool) {
        return (ownerAccumulatedTokensPerOutcome[_owner][_outcome].isWithdrawn);
    }

    /*
        @dev Returns true if the user bought units of a specific outcome

        @param _owner       Placements owner
        @param _outcomeId   Outcome id

        @return             true if the user bought units on a specific outcome
    */
    function hasTokenPlacements(address _owner, uint _outcome) private view returns(bool) {
        return (ownerAccumulatedTokensPerOutcome[_owner][_outcome].tokens > 0);
    }
    
}