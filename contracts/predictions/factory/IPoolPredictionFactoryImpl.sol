pragma solidity ^0.4.23;
import "../../token/IERC20Token.sol";
import "../types/pool/PoolPredictionCalculationMethods.sol";

/*
    @title IPoolPredictionFactoryImpl contract - An interface contract for the pool prediction factory.
*/
contract IPoolPredictionFactoryImpl {

    function createPoolPrediction(
        address _oracle, 
        uint _predictionEndTimeSeconds, 
        uint _optionBuyingEndTimeSeconds, 
        string _name, 
        IERC20Token _stox, 
        PoolPredictionCalculationMethods.PoolCalculationMethod _calculationMethod) 
        public;
    
    event PoolPredictionCreated(address indexed _creator, address indexed _newPrediction);

}
