pragma solidity ^0.4.18;
import "./PoolPredictionCalculationMethods.sol";

contract IPoolPredictionPrizeCalculation {
    
    function calculateWithdrawalAmount(PoolPredictionCalculationMethods.PoolCalculationMethod _method, 
                                        uint _ownerTotalTokensPlacements,
                                        uint _ownerTotalWinningOutcomeTokensPlacements, 
                                        uint _usersTotalWinningOutcomeTokensPlacements, 
                                        uint _tokenPool)
                                        constant
                                        public
                                        returns (uint _amount);
}
