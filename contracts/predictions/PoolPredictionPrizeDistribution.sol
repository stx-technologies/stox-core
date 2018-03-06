pragma solidity ^0.4.18;
import "../Ownable.sol";
import "../Utils.sol";

contract PoolPredictionPrizeDistribution is Ownable, Utils {

    /*
     *  Members
     */
    string      public version = "0.1";
    string      public name;

    /*
        @dev constructor

        @param _owner                       Prediction owner / operator
    */
    function PoolPredictionPrizeDistribution(string _name) 
        public
        Ownable(msg.sender)
        {
            name = _name;
        }

    /*
        @dev Allows specific calculation of winning amount

        @param _ownerWinningTokens          Total amount of tokens the owner put on the winning outcome
        @param _totalWinningTokens          Total amount of tokens all owners put on the winning outcome
        @param _tokenPool                   Total amount of tokens put by all owners on all outcomes

    */
    function calculateWithdrawalAmount(uint _ownerWinningTokens, uint _totalWinningTokens, uint _tokenPool)
        public
        returns (uint _amount)
        {
            return (safeMul(_ownerWinningTokens, _tokenPool) / _totalWinningTokens);
        }

}