pragma solidity ^0.4.18;
import "../../Ownable.sol";
import "./IUpgradablePredictionFactory.sol";

/*
    @title UpgradablePredictionFactory contract - A factory contract for generating predictions.
    It delegates the createPrediction() calls to the up-to-date prediction creation contract (address dispatched dynamically).
 */
contract UpgradablePredictionFactory is Ownable {

    /*
     * Members
     */
    address predictionFactoryImplRelay;
    
    function UpgradablePredictionFactory(address _predictionFactoryImplRelay) 
        public 
        Ownable(msg.sender) 
        {
            predictionFactoryImplRelay = _predictionFactoryImplRelay;
    }

    /*
        @dev Set a new PredictionFactoryImpl address

        @param _predictionFactoryImplRelay       PredictionFactoryImpl new address
    */
    function setPredictionFactoryImplRelay(address _predictionFactoryImplRelay) 
        public 
        ownerOnly 
        {
            predictionFactoryImplRelay = _predictionFactoryImplRelay;
    }

    
    /*
        @dev Fallback function to delegate calls to the relay contract

    */
    function() {
         
        if (!predictionFactoryImplRelay.delegatecall(msg.data)) 
           revert();
    }

}
