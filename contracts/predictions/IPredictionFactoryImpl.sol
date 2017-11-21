pragma solidity ^0.4.18;

/*
    @title IPredictionFactoryImpl contract - A interface contract for the predictions factory.
 */
contract IPredictionFactoryImpl {
    function createPoolPrediction(address _owner, address _oracle, uint _predictionEndTimeSeconds, uint _optionBuyingEndTimeSeconds, string _name) public returns(address); 
}
