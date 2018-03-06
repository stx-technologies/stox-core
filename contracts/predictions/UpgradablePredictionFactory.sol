pragma solidity ^0.4.18;
import "../Ownable.sol";
import "./PredictionFactoryRelayDispatcher.sol";
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
        @dev Set a new RelayDispatcher address

        @param _relayDispatcher       PredictionFactoryRelayDispatcher new address
    */
    function setRelayDispatcher(address _predictionFactoryImplRelay) 
        public 
        ownerOnly 
        {
            predictionFactoryImplRelay = _predictionFactoryImplRelay;
    }

    
    /*
        @dev Fallback function to delegate calls to the relay contract

    */
    function() {
        //PredictionFactoryImplRelay factoryRelayDispatcher = PredictionFactoryRelayDispatcher(relayDispatcher); 
        //address relay = factoryRelayDispatcher.getPredictionFactoryImplAddress();
        
        if (!predictionFactoryImplRelay.delegatecall(msg.data)) 
           revert();
    }

}
