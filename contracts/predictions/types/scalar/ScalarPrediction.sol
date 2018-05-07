pragma solidity ^0.4.23;
import "../../../oracles/types/SingleNumericOutcomeOracle.sol";
import "../../../token/IERC20Token.sol";
import "./ScalarPredictionPrizeDistribution.sol";
import "../../management/PredictionMetaData.sol";
import "../../prizeCalculations/IPrizeCalculation.sol";
import "../../methods/IPredictionMethods.sol";

/**
    @title Scalar prediction contract - Scalar predictions distributes tokens between all winners according to
    the distribution (calculation) method. The prediction winning outcome is decided by the oracle and can be any single integer.
*/

contract ScalarPrediction is ScalarPredictionPrizeDistribution, IPredictionMethods {

    
    /*
     *  Events
     */
    event TokensPlacedOnOutcome(address indexed _owner, int indexed _outcome, uint _tokenAmount);
    event UserRefunded(address indexed _owner, int indexed _outcome, uint _tokenAmount);

    /*
     *  Enum and Structs
     */

    // Holds user's tokens amount 
    struct UserTokens {
        uint    tokens;
        bool    hasWithdrawn;
    }

    /*
     *  Members
     */
    IERC20Token                                                   public stox;                // Stox ERC20 token
    int                                                           public winningOutcome;
    uint                                                          public tokenPool;           // Total tokens used to buy units in this prediction

    // Mapping to see all the total tokens bought per outcome, per user (user address -> outcome -> tokens)
    mapping(address => mapping(int => uint)) public ownerAccumulatedTokensPerOutcome;

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
    constructor(
        address _owner,
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
        @dev Allow any user to place tokens on his/her chosen outcome value. Note that users can make multiple placements, 
        on multiple outcomes.
        Before calling placeTokensFor the user should first call the approve(thisPredictionAddress, tokenAmount) on the
        stox token (or any other ERC20 token).

        @param _owner           The owner
        @param _tokenAmount     The amount of tokens invested in this outcome
        @param _outcome         The outcome the user predicts.
    */
    function placeTokensFor(address _owner, uint _tokenAmount, int _outcome)
            public
            statusIs(Status.Published)
            validAddress(_owner)
            greaterThanZero(_tokenAmount)
            {
        
        require(tokensPlacementEndTimeSeconds > now);

        tokenPool = safeAdd(tokenPool, _tokenAmount);
        ownerTotalTokenPlacements[_owner].tokens = safeAdd(ownerTotalTokenPlacements[_owner].tokens, _tokenAmount);

        ownerAccumulatedTokensPerOutcome[_owner][_outcome] =
             safeAdd(ownerAccumulatedTokensPerOutcome[_owner][_outcome], _tokenAmount); 
        
        assert(stox.transferFrom(_owner, this, _tokenAmount));
        
        emit TokensPlacedOnOutcome(_owner, _outcome, _tokenAmount);
    }

    /*
        @dev Allow any user to place tokens on a specific outcome.
        Before calling placeTokens the user should first call the approve(thisPredictionAddress, tokenAmount) on the
        stox token (or any other ERC20 token).

        @param _tokenAmount     The amount of tokens invested on this outcome
        @param _outcome         The outcome the user predicts.
    */
    function placeTokens(uint _tokenAmount, int _outcome) external  {
        placeTokensFor(msg.sender, _tokenAmount, _outcome);
    }

    /*
        @dev Allow the prediction owner to resolve the prediction.
        Before calling resolve() the oracle owner should first set the prediction outcome by calling setOutcome(thisPredictionAddress, winningOutcomeId)
        in the Oracle contract.
    */
    function resolve() public ownerOnly {
        require (((SingleNumericOutcomeOracle(oracleAddress)).isOutcomeSet(this)) &&
            (tokensPlacementEndTimeSeconds < now));

        winningOutcome = (SingleNumericOutcomeOracle(oracleAddress)).getOutcome(this);

        PredictionStatus.resolve(oracleAddress, bytes32(winningOutcome));
    }

    /*
        @dev After the prediction is resolved the user can withdraw tokens from his winning outcomes
        
     */
    function withdrawPrize() public statusIs(Status.Resolved) {
        require((ownerTotalTokenPlacements[msg.sender].tokens > 0) &&
            (!ownerTotalTokenPlacements[msg.sender].hasWithdrawn));

        distributePrizeToUser(
            stox, 
            ownerTotalTokenPlacements[msg.sender].tokens,
            ownerAccumulatedTokensPerOutcome[msg.sender][winningOutcome], 
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
                                            0, 
                                            tokenPool));
    
    }

    /*
        @dev Allow to prediction owner / operator to cancel the user's placements and refund the tokens.

        @param _owner           Placements owner
        @param _outcome         Outcome to refund
    */
    function refundUser(address _owner, int _outcome) public ownerOnly {
        require (status != Status.Resolved);
                
        performRefund(_owner, _outcome);
        
    }

    /*
        @dev Allow the user to cancel his placements and refund the tokens he invested.
        Can be called only after the prediction is canceled.

        @param _outcome     Outcome to refund
    */
    function getRefund(int _outcome) public statusIs(Status.Canceled) {
        performRefund(msg.sender, _outcome);
    }

    /*
        @dev Refund a specific user's token placements and cancel them

        @param _owner       Placements owner
        @param _outcome     Outcome to refund
    */

    function performRefund(address _owner, int _outcome) private {
        require((tokenPool > 0) &&
                hasTokenPlacements(_owner, _outcome));

        uint refundAmount = ownerAccumulatedTokensPerOutcome[_owner][_outcome];

        if (refundAmount > 0) {
            tokenPool = safeSub(tokenPool, refundAmount);
            ownerTotalTokenPlacements[_owner].tokens = safeSub(ownerTotalTokenPlacements[_owner].tokens, refundAmount);
            ownerAccumulatedTokensPerOutcome[_owner][_outcome] = 0;
            stox.transfer(_owner, refundAmount); // Refund the user
        }

        emit UserRefunded(_owner, _outcome, refundAmount);
    }

    /*
        @dev Returns true if the user bought units of a specific outcome

        @param _owner       Placements owner
        @param _outcome     Outcome 

        @return             true if the user bought units on a specific outcome
    */
    function hasTokenPlacements(address _owner, int _outcome) private view returns(bool) {
        return (ownerAccumulatedTokensPerOutcome[_owner][_outcome] > 0);
    }
    
}