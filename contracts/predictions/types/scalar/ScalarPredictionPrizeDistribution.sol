pragma solidity ^0.4.18;
import "../../management/PredictionTiming.sol";
import "./IScalarPredictionPrizeDistribution.sol";
import "./ScalarPredictionPrizeCalculation.sol";
import "../../../token/IERC20Token.sol";

/*
    @title ScalarPredictionPrizeDistribution contract - holds the pool prediction prize distribution implementation
*/
contract ScalarPredictionPrizeDistribution is PredictionTiming, ScalarPredictionPrizeCalculation, IScalarPredictionPrizeDistribution {

    
    /*
     * Events
     */
    event PrizeDistributed(address indexed _owner, uint _tokenAmount, IERC20Token _token);
    

    /*
        @dev constructor

        @param _predictionEndTimeSeconds                Prediction end time, in seconds
        @param _buyingEndTimeSeconds                    Placements buying end time, in seconds
    */
    function ScalarPredictionPrizeDistribution(uint _predictionEndTimeSeconds, uint _buyingEndTimeSeconds)
        public
        PredictionTiming(_predictionEndTimeSeconds, _buyingEndTimeSeconds) 
        {}

    /*
        @dev Distribute a prize for a user, by method

        @param _token                                       ERC20token token
        @param _method                                      Method of calculating prizes
        @param _ownerTotalTokensPlacements                  Total amount of tokens the owner put on any outcome
        @param _ownerTotalWinningOutcomeTokensPlacements    Total amount of tokens the owner put on the winning outcome
        @param _totalWinningOutcomeTokens                   Total amount of tokens all owners put on the winning outcome
        @param _tokenPool                                   Total amount of tokens put by all owners on all outcomes

    */
    function distributePrizeToUser(IERC20Token _token, 
                                    ScalarPredictionCalculationMethods.ScalarCalculationMethod _method, 
                                    uint _ownerTotalTokensPlacements,
                                    uint _ownerTotalWinningOutcomeTokensPlacements, 
                                    uint _tokenPool)
        public
        {
            require(_ownerTotalTokensPlacements > 0);

            uint userPrizeTokens = 0;

            userPrizeTokens = calculatePrizeAmount(_method,
                                                   _ownerTotalTokensPlacements,     
                                                   _ownerTotalWinningOutcomeTokensPlacements,
                                                   _tokenPool);

            if (userPrizeTokens > 0) {
                _token.transfer(msg.sender, userPrizeTokens);
            } else {
                revert();
            }

            PrizeDistributed(msg.sender, userPrizeTokens, _token);
        }
}
