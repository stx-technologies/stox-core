pragma solidity ^0.4.23;
import "./ScalarPredictionCalculationMethods.sol";
import "../../../token/IERC20Token.sol";

/*
    @title IScalarPredictionPrizeDistribution contract - An interface contract for the scalar prediction prize distribution.
*/
contract IScalarPredictionPrizeDistribution {
    function distributePrizeToUser(
        IERC20Token _token, 
        ScalarPredictionCalculationMethods.ScalarCalculationMethod _method, 
        uint _ownerTotalTokensPlacements,
        uint _ownerTotalWinningOutcomeTokensPlacements, 
        uint _tokenPool)
        public;
    
    event PrizeDistributed(address indexed _owner, uint _tokenAmount, IERC20Token _token);
}
