pragma solidity ^0.4.23;
import "./PoolPredictionCalculationMethods.sol";
import "../../../token/IERC20Token.sol";

/*
    @title IPoolPredictionPrizeDistribution contract - An interface contract for the pool prediction prize distribution.
*/
contract IPoolPredictionPrizeDistribution {
    function distributePrizeToUser(
        IERC20Token _token, 
        PoolPredictionCalculationMethods.PoolCalculationMethod _method, 
        uint _ownerTotalTokensPlacements,
        uint _ownerTotalWinningOutcomeTokensPlacements, 
        uint _usersTotalWinningOutcomeTokensPlacements, 
        uint _tokenPool)
        public;
    
    event PrizeDistributed(address indexed _owner, uint _tokenAmount, IERC20Token _token);
}
