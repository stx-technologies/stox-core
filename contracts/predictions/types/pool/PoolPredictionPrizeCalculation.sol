pragma solidity ^0.4.18;
import "../../../Utils.sol";   
import "./IPoolPredictionPrizeCalculation.sol";

contract PoolPredictionPrizeCalculation is Utils, IPoolPredictionPrizeCalculation {

     
    /*
        @dev Allows specific calculation of winning amount

        @param _method                                  Method of calculating prizes
        @param _ownerWinningOutcomeTokens               Total amount of tokens the owner put on the winning outcome
        @param _totalWinningOutcomeTokens               Total amount of tokens all owners put on the winning outcome
        @param _tokenPool                               Total amount of tokens put by all owners on all outcomes

    */
    function calculateWithdrawalAmount(PoolPredictionPrizeLib.CalculationMethod _method, 
                                        uint _ownerWinningTokens, 
                                        uint _totalWinningTokens, 
                                        uint _tokenPool)
        constant
        returns (uint _amount)
        {
           uint returnValue = 0;
           
           if (_method == PoolPredictionPrizeLib.CalculationMethod.back2back) {
               returnValue = _ownerWinningTokens;
           } else if (_method == PoolPredictionPrizeLib.CalculationMethod.relative) {
               returnValue = safeMul(_ownerWinningTokens, _tokenPool) / _totalWinningTokens;
           }

           return returnValue;
        }
}