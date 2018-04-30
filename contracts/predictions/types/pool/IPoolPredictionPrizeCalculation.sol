pragma solidity ^0.4.23;
import "./PoolPredictionCalculationMethods.sol";

/*
    @title IPoolPredictionPrizeCalculation contract - An interface contract for the pool prediction prize calculation.
*/
contract IPoolPredictionPrizeCalculation {
    
    function calculatePrizeAmount(
        PoolPredictionCalculationMethods.PoolCalculationMethod _method, 
        uint _ownerTotalTokensPlacements,
        uint _ownerTotalWinningOutcomeTokensPlacements, 
        uint _usersTotalWinningOutcomeTokensPlacements, 
        uint _tokenPool)
        constant
        public
        returns (uint _amount);
        
}
