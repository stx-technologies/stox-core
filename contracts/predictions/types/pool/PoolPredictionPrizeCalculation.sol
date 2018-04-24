pragma solidity ^0.4.18;
import "../../../Utils.sol";   
import "./IPoolPredictionPrizeCalculation.sol";

/*
    @title PoolPredictionPrizeCalculation contract - holds the pool prediction prize calculation implementation
*/
contract PoolPredictionPrizeCalculation is Utils, IPoolPredictionPrizeCalculation {
     
    /*
        @dev Allows specific calculation of winning amount
        Note - if _usersTotalWinningOutcomeTokensPlacements equals 0 and the calculation method is not break even, 
        in the current implementation the tokens will remain in the prediction. In future implementation, there needs to be a mechanism and logic
        for releasing the funds. 

        @param _method                                      Method of calculating prizes
        @param _ownerTotalTokensPlacements                  Total amount of tokens the owner put on any outcome
        @param _ownerTotalWinningOutcomeTokensPlacements    Total amount of tokens the owner put on the winning outcome
        @param _usersTotalWinningOutcomeTokensPlacements    Total amount of tokens all owners put on the winning outcome
        @param _tokenPool                                   Total amount of tokens put by all owners on all outcomes

    */
    function calculatePrizeAmount(PoolPredictionCalculationMethods.PoolCalculationMethod _method, 
                                  uint _ownerTotalTokensPlacements,
                                  uint _ownerTotalWinningOutcomeTokensPlacements, 
                                  uint _usersTotalWinningOutcomeTokensPlacements, 
                                  uint _tokenPool)
        constant
        public
        returns (uint _amount)
        {
           uint returnValue = 0;
           
           if (_method == PoolPredictionCalculationMethods.PoolCalculationMethod.breakEven) {
               returnValue = _ownerTotalTokensPlacements;
           } else if (_method == PoolPredictionCalculationMethods.PoolCalculationMethod.relative) {
               assert(_usersTotalWinningOutcomeTokensPlacements > 0);
               returnValue = safeMul(_ownerTotalWinningOutcomeTokensPlacements, _tokenPool) / _usersTotalWinningOutcomeTokensPlacements;
           }

           return returnValue;
        }
}
