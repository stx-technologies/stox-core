pragma solidity ^0.4.18;
import "./PoolPrediction.sol";
import "./IPredictionFactoryImpl.sol";
import "../token/IERC20Token.sol";

/*
    @title PredictionFactoryImpl contract - The implementation for the Prediction Factory
 */
contract PredictionFactoryImpl is IPredictionFactoryImpl, Utils {

    IERC20Token public stox; // Stox ERC20 token

    function PredictionFactoryImpl(IERC20Token _stox) public validAddress(_stox) {
        stox = _stox;
    }

    function createPoolPrediction(address _owner, address _oracle, uint _predictionEndTimeSeconds, uint _optionBuyingEndTimeSeconds, string _name) public returns(address) {
        PoolPrediction newPrediction = new PoolPrediction(_owner, _oracle, _predictionEndTimeSeconds, _optionBuyingEndTimeSeconds, _name, stox);

        return (address(newPrediction));
    }
}
