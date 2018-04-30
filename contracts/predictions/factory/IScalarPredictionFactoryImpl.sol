pragma solidity ^0.4.23;
import "../../token/IERC20Token.sol";
import "../types/scalar/ScalarPredictionCalculationMethods.sol";

/*
    @title IScalarPredictionFactoryImpl contract - An interface contract for the scalar prediction factory.
 */
contract IScalarPredictionFactoryImpl {

    function createScalarPrediction(
        address _oracle, 
        uint _predictionEndTimeSeconds, 
        uint _optionBuyingEndTimeSeconds, 
        string _name, 
        IERC20Token _stox, 
        ScalarPredictionCalculationMethods.ScalarCalculationMethod _calculationMethod) 
        public;
    
    event ScalarPredictionCreated(address indexed _creator, address indexed _newPrediction);
    
}
