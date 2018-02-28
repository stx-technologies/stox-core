pragma solidity ^0.4.18;
import "./PoolPrediction.sol";
import "./IUpgradablePredictionFactory.sol";
import "../token/IERC20Token.sol";

/*
    @title PredictionFactoryImpl contract - The implementation for the Prediction Factory
 */
contract PredictionFactoryImpl is IUpgradablePredictionFactory, Utils {

    //IERC20Token public astox; // Stox ERC20 token

    event PoolPredictionCreated(address indexed _creator, address indexed _newPrediction);

    function PredictionFactoryImpl() public {}

    function createPoolPrediction(address _oracle, uint _predictionEndTimeSeconds, uint _optionBuyingEndTimeSeconds, string _name, IERC20Token _stox) public validAddress(_stox) {
        PoolPrediction newPrediction = new PoolPrediction(msg.sender, _oracle, _predictionEndTimeSeconds, _optionBuyingEndTimeSeconds, _name, _stox);

        PoolPredictionCreated(msg.sender, address(newPrediction));
        //return (address(newPrediction));
    }
}
