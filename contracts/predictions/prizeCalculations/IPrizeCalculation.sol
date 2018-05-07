pragma solidity ^0.4.23;

contract IPrizeCalculation {
    function calculatePrizeAmount(
        uint _ownerTotalTokensPlacements,
        uint _ownerTotalWinningOutcomeTokensPlacements, 
        uint _usersTotalWinningOutcomeTokensPlacements, 
        uint _tokenPool)
        constant
        public
        returns (uint _amount);
}