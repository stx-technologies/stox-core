pragma solidity ^0.4.23;
import "../../management/PredictionTiming.sol";
import "./IPoolPredictionPrizeDistribution.sol";
import "../../../token/IERC20Token.sol";

/*
    @title PoolPredictionPrizeDistribution contract - holds the pool prediction prize distribution implementation
*/
contract PoolPredictionPrizeDistribution is PredictionTiming, IPoolPredictionPrizeDistribution {
    
    /*
     * Events
     */
    event PrizeDistributed(address indexed _owner, uint _tokenAmount, IERC20Token _token);
    
    /*
        @dev Distribute a prize for a user, by method

        @param _token                                       ERC20token token
        @param _ownerTotalTokensPlacements                  Total amount of tokens the owner put on any outcome
        @param _ownerTotalWinningOutcomeTokensPlacements    Total amount of tokens the owner put on the winning outcome
        @param _usersTotalWinningOutcomeTokensPlacements    Total amount of tokens all users put on the winning outcome
        @param _tokenPool                                   Total amount of tokens put by all owners on all outcomes

    */
    function distributePrizeToUser(
        IERC20Token _token, 
        uint _ownerTotalTokensPlacements,
        uint _ownerTotalWinningOutcomeTokensPlacements, 
        uint _usersTotalWinningOutcomeTokensPlacements, 
        uint _tokenPool)
        public
        {
            require(_ownerTotalTokensPlacements > 0);

            uint userPrizeTokens = 0;

            userPrizeTokens = prizeCalculation.calculatePrizeAmount(_ownerTotalTokensPlacements,     
                                                   _ownerTotalWinningOutcomeTokensPlacements,
                                                   _usersTotalWinningOutcomeTokensPlacements,
                                                   _tokenPool);

            if (userPrizeTokens > 0) {
                _token.transfer(msg.sender, userPrizeTokens);
            } else {
                revert();
            }

            emit PrizeDistributed(msg.sender, userPrizeTokens, _token);
        }
}

