pragma solidity ^0.4.18;
import "../../../Utils.sol";   
import "./IPoolPredictionPrizeCalculation.sol";

contract PoolPredictionPrizeCalculation is Utils, IPoolPredictionPrizeCalculation {

     
    /*
        @dev Allows specific calculation of winning amount

        @param _method                                      Method of calculating prizes
        @param _ownerTotalTokensPlacements                  Total amount of tokens the owner put on any outcome
        @param _ownerTotalWinningOutcomeTokensPlacements    Total amount of tokens the owner put on the winning outcome
        @param _totalWinningOutcomeTokens                   Total amount of tokens all owners put on the winning outcome
        @param _tokenPool                                   Total amount of tokens put by all owners on all outcomes

    */
    function calculateWithdrawalAmount(PoolPredictionCalculationMethods.PoolCalculationMethod _method, 
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
               require(_usersTotalWinningOutcomeTokensPlacements > 0);
               returnValue = safeMul(_ownerTotalWinningOutcomeTokensPlacements, _tokenPool) / _usersTotalWinningOutcomeTokensPlacements;
           }

           return returnValue;
        }
}
