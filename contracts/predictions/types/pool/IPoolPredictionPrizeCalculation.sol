pragma solidity ^0.4.18;
import "./PoolPredictionPrizeLib.sol";

contract IPoolPredictionPrizeCalculation {
    
    function calculateWithdrawalAmount(PoolPredictionPrizeLib.CalculationMethod _method, 
                                        uint _ownerWinningTokens, 
                                        uint _totalWinningTokens, 
                                        uint _tokenPool) 
                                        constant returns (uint _amount);
}