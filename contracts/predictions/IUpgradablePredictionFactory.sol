pragma solidity ^0.4.18;
import "../token/IERC20Token.sol";

contract IUpgradablePredictionFactory {
    function createPoolPrediction(address _oracle, uint _predictionEndTimeSeconds, uint _optionBuyingEndTimeSeconds, string _name, IERC20Token _stox) public;
    event PoolPredictionCreated(address indexed _creator, address indexed _newPrediction);
}