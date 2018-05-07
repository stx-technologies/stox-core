pragma solidity ^0.4.23;
import "../../Utils.sol";   
import "./IPrizeCalculation.sol";

/*
    @title PrizeCalculationBreakEven contract - holds the break even prize calculation implementation
*/
contract PrizeCalculationRelative is Utils, IPrizeCalculation {
     
    /*
        @dev Allows a calculation of winning amount based on that the user gets the amount placed
        Note - if _usersTotalWinningOutcomeTokensPlacements equals 0 and the calculation method is not break even, 
        in the current implementation the tokens will remain in the prediction. In future implementation, there needs to be a mechanism and logic
        for releasing the funds.

        @param _ownerTotalTokensPlacements                  Total amount of tokens the owner put on any outcome
        @param _ownerTotalWinningOutcomeTokensPlacements    Total amount of tokens the owner put on the winning outcome
        @param _usersTotalWinningOutcomeTokensPlacements    Total amount of tokens all owners put on the winning outcome
        @param _tokenPool                                   Total amount of tokens put by all owners on all outcomes

    */
    function calculatePrizeAmount(
        uint _ownerTotalTokensPlacements,
        uint _ownerTotalWinningOutcomeTokensPlacements, 
        uint _usersTotalWinningOutcomeTokensPlacements, 
        uint _tokenPool)
        constant
        public
        returns (uint _amount)
        {
            uint returnValue = 0;

            assert(_usersTotalWinningOutcomeTokensPlacements > 0);
            returnValue = safeMul(_ownerTotalWinningOutcomeTokensPlacements, _tokenPool) / _usersTotalWinningOutcomeTokensPlacements;
           
            return returnValue;
        }
}