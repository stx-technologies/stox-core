pragma solidity ^0.4.23;
import "../types/pool/PoolPrediction.sol";
import "./IPoolPredictionFactoryImpl.sol";
import "../../token/IERC20Token.sol";
import "../types/pool/PoolPredictionPrizeDistribution.sol";

/*
    @title PoolPredictionFactoryImpl contract - The implementation for the Pool Prediction Factory
 */
contract PoolPredictionFactoryImpl is IPoolPredictionFactoryImpl, Utils {

    /*
        Events
    */
    event PoolPredictionCreated(address indexed _creator, address indexed _newPrediction);
    
    /*
        @dev constructor
    */
    constructor() public {}

    /*
        @dev Create a Pool Prediction instance

        @param _oracle                      Oracle
        @param _predictionEndTimeSeconds    Prediction end time, in seconds
        @param _buyingEndTimeSeconds        Buying outcome end time, in seconds
        @name  _name                        Prediction name
        @param _stox                        Token 
        @param _calculationMethod           Prize calculation method
    */
    function createPoolPrediction(
        address _oracle, 
        uint _predictionEndTimeSeconds, 
        uint _buyingEndTimeSeconds, 
        string _name, 
        IERC20Token _stox,
        PoolPredictionCalculationMethods.PoolCalculationMethod _calculationMethod) 
        public 
        validAddress(_stox) 
        {
            PoolPrediction newPrediction = new PoolPrediction(
                                                msg.sender, 
                                                _oracle, 
                                                _predictionEndTimeSeconds, 
                                                _buyingEndTimeSeconds, 
                                                _name, 
                                                _stox, 
                                                _calculationMethod);

            emit PoolPredictionCreated(msg.sender, address(newPrediction));
    }
}

