pragma solidity ^0.4.18;
import "./ScalarPredictionCalculationMethods.sol";
import "../../../token/IERC20Token.sol";

contract IScalarPredictionPrizeDistribution {
    function distributePrizeToUser(IERC20Token _token, 
                                    ScalarPredictionCalculationMethods.ScalarCalculationMethod _method, 
                                    uint _ownerTotalTokensPlacements,
                                    uint _ownerTotalWinningOutcomeTokensPlacements, 
                                    uint _tokenPool)
                                    public;
    event PrizeWithdrawn(address indexed _owner, uint _tokenAmount, IERC20Token _token);
}
