pragma solidity ^0.4.18;
import "./ScalarPredictionCalculationMethods.sol";

contract IScalarPredictionPrizeCalculation {
    
    function calculateWithdrawalAmount(ScalarPredictionCalculationMethods.ScalarCalculationMethod _method, 
                                        uint _ownerTotalTokensPlacements,
                                        uint _ownerTotalWinningOutcomeTokensPlacements, 
                                        uint _tokenPool)
                                        constant
                                        public
                                        returns (uint _amount);
}