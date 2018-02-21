pragma solidity ^0.4.18;

contract IUpgradablePredictionFactory {
    function createPoolPrediction(IPredictionFactoryImpl _factory, address _oracle, uint _predictionEndTimeSeconds, uint _optionBuyingEndTimeSeconds, string _name)
}