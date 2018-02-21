pragma solidity ^0.4.18;
import "./IPredictionFactoryImpl.sol";
import "../Ownable.sol";

/*
    @title PredictionFactory contract - A factory contract for generating predictions.
    It holds a factory interface object so we can update the prediction code without deploying a new prediction factory to the ethereum netowrk.
 */
contract PredictionFactory is Ownable {

    event PoolPredictionCreated(address indexed _creator, address indexed _newPrediction);
    
    //IPredictionFactoryImpl public factory;
    address newCreatedPredictionAddress;

    /*
    function PredictionFactory(IPredictionFactoryImpl _factory) public Ownable(msg.sender) {
        factory = _factory;
    }

    function setFactory(IPredictionFactoryImpl _factory) public ownerOnly {
        require ((address(_factory) != address(this)) && (address(_factory) != 0x0));

        factory = _factory;
    }
    */

    function createPoolPrediction(IPredictionFactoryImpl _factory, address _oracle, uint _predictionEndTimeSeconds, uint _optionBuyingEndTimeSeconds, string _name) public {
        address newPrediction = _factory.createPoolPrediction(msg.sender, _oracle, _predictionEndTimeSeconds, _optionBuyingEndTimeSeconds, _name);

        PoolPredictionCreated(msg.sender, newPrediction);
        //return (address(newPrediction));
        newCreatedPredictionAddress = address(newPrediction);
    }
}
