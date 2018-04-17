pragma solidity ^0.4.18;
import "./ScalarPredictionCalculationMethods.sol";

/*
    @title IScalarPredictionPrizeCalculation contract - An interface contract for the scalar prediction prize calculation.
*/
contract IScalarPredictionPrizeCalculation {
    
    function calculatePrizeAmount(ScalarPredictionCalculationMethods.ScalarCalculationMethod _method, 
                                        uint _ownerTotalTokensPlacements,
                                        uint _ownerTotalWinningOutcomeTokensPlacements, 
                                        uint _tokenPool)
                                        constant
                                        public
                                        returns (uint _amount);
}