pragma solidity ^0.4.18;
//import "../../../Ownable.sol";
//import "../../../Utils.sol";
import "../../management/PredictionTiming.sol";
import "./IPoolPredictionPrizeDistribution.sol";
import "./PoolPredictionPrizeCalculation.sol";
import "../../../token/IERC20Token.sol";

contract PoolPredictionPrizeDistribution is PredictionTiming, PoolPredictionPrizeCalculation, IPoolPredictionPrizeDistribution {

    /*
     *  Members
     */
    //string      public name;

    /*
     * Events
     */
    event TokenPlacementsWithdrawn(address indexed _owner, uint _tokenAmount);
    

    /*
        @dev constructor

        @param _predictionEndTimeSeconds                Prediction end time, in seconds
        @param _buyingEndTimeSeconds                    Placements buying end time, in seconds
    */
    function PoolPredictionPrizeDistribution(uint _predictionEndTimeSeconds, uint _buyingEndTimeSeconds)
        public
        PredictionTiming(_predictionEndTimeSeconds, _buyingEndTimeSeconds) 
        {}

    function getWithdrawalAmount(PoolPredictionPrizeLib.CalculationMethod _method, 
                                    uint _ownerWinningTokens, 
                                    uint _totalWinningTokens, 
                                    uint _tokenPool) 
        internal 
        returns (uint _amount)
        {
            return (calculateWithdrawalAmount(_method,_ownerWinningTokens,_totalWinningTokens,_tokenPool));
        }
    
    function distributePrizeToUser(IERC20Token _token, 
                                    PoolPredictionPrizeLib.CalculationMethod _method, 
                                    uint _ownerWinningTokens, 
                                    uint _totalWinningTokens, 
                                    uint _tokenPool)
        public
        {
            uint userWinTokens = 0;

            userWinTokens = getWithdrawalAmount(_method, _ownerWinningTokens, _totalWinningTokens, _tokenPool);

            if (userWinTokens > 0) {
                _token.transfer(msg.sender, userWinTokens);
            }

            TokenPlacementsWithdrawn(msg.sender, userWinTokens);
        }
    

}