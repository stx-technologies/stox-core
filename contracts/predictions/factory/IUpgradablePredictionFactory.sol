pragma solidity ^0.4.18;
import "../../token/IERC20Token.sol";
import "../types/pool/PoolPredictionCalculationMethods.sol";
import "../types/scalar/ScalarPredictionCalculationMethods.sol";


contract IUpgradablePredictionFactory {
    function createPoolPrediction(address _oracle, 
                                    uint _predictionEndTimeSeconds, 
                                    uint _optionBuyingEndTimeSeconds, 
                                    string _name, 
                                    IERC20Token _stox, 
                                    PoolPredictionCalculationMethods.PoolCalculationMethod _calculationMethod) 
                                    public;
    
    event PoolPredictionCreated(address indexed _creator, address indexed _newPrediction);

    function createScalarPrediction(address _oracle, 
                                    uint _predictionEndTimeSeconds, 
                                    uint _optionBuyingEndTimeSeconds, 
                                    string _name, 
                                    IERC20Token _stox, 
                                    ScalarPredictionCalculationMethods.ScalarCalculationMethod _calculationMethod) 
                                    public;
    
    event ScalarPredictionCreated(address indexed _creator, address indexed _newPrediction);

}