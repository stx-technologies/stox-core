pragma solidity ^0.4.18;
import "../types/pool/PoolPrediction.sol";
import "./IUpgradablePredictionFactory.sol";
import "../../token/IERC20Token.sol";
import "../types/pool/PoolPredictionPrizeDistribution.sol";

/*
    @title PredictionFactoryImpl contract - The implementation for the Prediction Factory
 */
contract PredictionFactoryImpl is IUpgradablePredictionFactory, Utils {

    event PoolPredictionCreated(address indexed _creator, address indexed _newPrediction);

    function PredictionFactoryImpl() public {}

    /*
        @dev Create a Pool Prediction instance

        @param _oracle                      Oracle
        @param _predictionEndTimeSeconds    Prediction end time, in seconds
        @param _buyingEndTimeSeconds        Buying outcome end time, in seconds
        @name  _name                        Prediction name
        @param _stox                        Token 
        @param _calculationMethod             Prize calculation method
    */
    function createPoolPrediction(address _oracle, 
            uint _predictionEndTimeSeconds, 
            uint _buyingEndTimeSeconds, 
            string _name, 
            IERC20Token _stox,
            PoolPredictionPrizeLib.CalculationMethod _calculationMethod) 
        public 
        validAddress(_stox) 
        {
            PoolPrediction newPrediction = new PoolPrediction(msg.sender, 
                                                _oracle, 
                                                _predictionEndTimeSeconds, 
                                                _buyingEndTimeSeconds, 
                                                _name, 
                                                _stox, 
                                                _calculationMethod);

            PoolPredictionCreated(msg.sender, address(newPrediction));
    }
}
