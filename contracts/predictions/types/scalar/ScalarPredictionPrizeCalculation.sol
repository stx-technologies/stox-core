pragma solidity ^0.4.18;
import "../../../Utils.sol";   
import "./IScalarPredictionPrizeCalculation.sol";

/*
    @title ScalarPredictionPrizeCalculation contract - holds the pool prediction prize calculation implementation
*/
contract ScalarPredictionPrizeCalculation is Utils, IScalarPredictionPrizeCalculation {

     
    /*
        @dev Allows specific calculation of winning amount

        @param _method                                      Method of calculating prizes
        @param _ownerTotalTokensPlacements                  Total amount of tokens the owner put on any outcome
        @param _ownerTotalWinningOutcomeTokensPlacements    Total amount of tokens the owner put on the winning outcome
        @param _totalWinningOutcomeTokens                   Total amount of tokens all owners put on the winning outcome
        @param _tokenPool                                   Total amount of tokens put by all owners on all outcomes

    */
    function calculatePrizeAmount(ScalarPredictionCalculationMethods.ScalarCalculationMethod _method, 
                                  uint _ownerTotalTokensPlacements,
                                  uint _ownerTotalWinningOutcomeTokensPlacements, 
                                  uint _tokenPool)
        constant
        public
        returns (uint _amount)
        {
           uint returnValue = 0;
           
           if (_method == ScalarPredictionCalculationMethods.ScalarCalculationMethod.breakEven) {
               returnValue = _ownerTotalTokensPlacements;
           } 

           return returnValue;
        }
}