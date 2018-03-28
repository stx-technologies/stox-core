pragma solidity ^0.4.18;
import "./PoolPredictionCalculationMethods.sol";
import "../../../token/IERC20Token.sol";

contract IPoolPredictionPrizeDistribution {
    function distributePrizeToUser(IERC20Token _token, 
                                    PoolPredictionCalculationMethods.PoolCalculationMethod _method, 
                                    uint _ownerTotalTokensPlacements,
                                    uint _ownerTotalWinningOutcomeTokensPlacements, 
                                    uint _usersTotalWinningOutcomeTokensPlacements, 
                                    uint _tokenPool)
                                    public;
    event PrizeWithdrawn(address indexed _owner, uint _tokenAmount, IERC20Token _token);
}
