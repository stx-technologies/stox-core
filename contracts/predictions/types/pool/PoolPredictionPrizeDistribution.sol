pragma solidity ^0.4.18;
import "../../management/PredictionTiming.sol";
import "./IPoolPredictionPrizeDistribution.sol";
import "./PoolPredictionPrizeCalculation.sol";
import "../../../token/IERC20Token.sol";

contract PoolPredictionPrizeDistribution is PredictionTiming, PoolPredictionPrizeCalculation, IPoolPredictionPrizeDistribution {

    
    /*
     * Events
     */
    event PrizeWithdrawn(address indexed _owner, uint _tokenAmount, IERC20Token _token);
    

    /*
        @dev constructor

        @param _predictionEndTimeSeconds                Prediction end time, in seconds
        @param _buyingEndTimeSeconds                    Placements buying end time, in seconds
    */
    function PoolPredictionPrizeDistribution(uint _predictionEndTimeSeconds, uint _buyingEndTimeSeconds)
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
                                    PoolPredictionCalculationMethods.PoolCalculationMethod _method, 
                                    uint _ownerTotalTokensPlacements,
                                    uint _ownerTotalWinningOutcomeTokensPlacements, 
                                    uint _usersTotalWinningOutcomeTokensPlacements, 
                                    uint _tokenPool)
        public
        {
            require(_ownerTotalTokensPlacements > 0);

            uint userPrizeTokens = 0;

            userPrizeTokens = calculateWithdrawalAmount(_method,
                                                        _ownerTotalTokensPlacements,     
                                                        _ownerTotalWinningOutcomeTokensPlacements,
                                                        _usersTotalWinningOutcomeTokensPlacements,
                                                        _tokenPool);

            if (userPrizeTokens > 0) {
                _token.transfer(msg.sender, userPrizeTokens);
            }

            PrizeWithdrawn(msg.sender, userPrizeTokens, _token);
        }
}

