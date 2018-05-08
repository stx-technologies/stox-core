pragma solidity ^0.4.23;

/*
    @title IPrizeCalculation contract - An interface contract for predictions prize calculation methods.
*/
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