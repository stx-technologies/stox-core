pragma solidity ^0.4.18;
import "./PoolPredictionPrizeLib.sol";
import "../../../token/IERC20Token.sol";

contract IPoolPredictionPrizeDistribution {
    function getWithdrawalAmount(PoolPredictionPrizeLib.CalculationMethod _method, 
                                    uint _ownerWinningTokens, 
                                    uint _totalWinningTokens, 
                                    uint _tokenPool) 
                                    internal returns (uint _amount);
    function distributePrizeToUser(IERC20Token _token, 
                                    PoolPredictionPrizeLib.CalculationMethod _method, 
                                    uint _ownerWinningTokens, 
                                    uint _totalWinningTokens, 
                                    uint _tokenPool) 
                                    public;
    event TokenPlacementsWithdrawn(address indexed _owner, uint _tokenAmount);
}