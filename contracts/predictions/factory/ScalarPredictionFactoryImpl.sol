pragma solidity ^0.4.18;
import "../types/scalar/ScalarPrediction.sol";
import "./IScalarPredictionFactoryImpl.sol";
import "../../token/IERC20Token.sol";
import "../types/scalar/ScalarPredictionPrizeDistribution.sol";

/*
    @title PredictionFactoryImpl contract - The implementation for the Prediction Factory
 */
contract ScalarPredictionFactoryImpl is IScalarPredictionFactoryImpl, Utils {

    event ScalarPredictionCreated(address indexed _creator, address indexed _newPrediction);

    function ScalarPredictionFactoryImpl() public {}
    
    /*
        @dev Create a Scalar Prediction instance

        @param _oracle                      Oracle
        @param _predictionEndTimeSeconds    Prediction end time, in seconds
        @param _buyingEndTimeSeconds        Buying outcome end time, in seconds
        @name  _name                        Prediction name
        @param _stox                        Token 
        @param _calculationMethod           Prize calculation method
    */
    
    function createScalarPrediction(address _oracle, 
            uint _predictionEndTimeSeconds, 
            uint _buyingEndTimeSeconds, 
            string _name, 
            IERC20Token _stox,
            ScalarPredictionCalculationMethods.ScalarCalculationMethod _calculationMethod) 
        public 
        validAddress(_stox) 
        {
            ScalarPrediction newPrediction = new ScalarPrediction(msg.sender, 
                                                _oracle, 
                                                _predictionEndTimeSeconds, 
                                                _buyingEndTimeSeconds, 
                                                _name, 
                                                _stox, 
                                                _calculationMethod);

            ScalarPredictionCreated(msg.sender, address(newPrediction));
    }
}

