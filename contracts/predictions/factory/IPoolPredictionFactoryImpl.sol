pragma solidity ^0.4.23;
import "../../token/IERC20Token.sol";
import "../prizeCalculations/IPrizeCalculation.sol";

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
        IPrizeCalculation _prizeCalculation) 
        public;
    
    event PoolPredictionCreated(address indexed _creator, address indexed _newPrediction);

}
