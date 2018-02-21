pragma solidity ^0.4.18;
import "../Ownable.sol";
import "./PredictionFactoryRelayDispatcher.sol";
import "./IPredictionFactoryImpl.sol";

/*
    @title UpgradablePredictionFactory contract - A factory contract for generating predictions.
    It delegates the createPrediction() calls to the up-to-date prediction creation contract (address dispatched dynamically).
 */
contract UpgradablePredictionFactory is Ownable {

    /*
     * Members
     */

    address relayDispatcher;
    address newCreatedPredictionAddress; 
    IPredictionFactoryImpl public factory;
    
    function UpgradablePredictionFactory(address _relayDispatcher, IPredictionFactoryImpl _factory) 
        public 
        Ownable(msg.sender) 
        {
            relayDispatcher = _relayDispatcher;
            factory = _factory;
    }
    
    function setFactory(IPredictionFactoryImpl _factory) public ownerOnly {
        require ((address(_factory) != address(this)) && (address(_factory) != 0x0));

        factory = _factory;
    }

    /*
        @dev Fallback function to delegate calls to the relay contract

    */
    function() {
        PredictionFactoryRelayDispatcher currentRelayVersionContract = PredictionFactoryRelayDispatcher(relayDispatcher); 
        var currentRelayVersionAddress = currentRelayVersionContract.getPredictionFactoryImplAddress();
        
        if (!currentRelayVersionAddress.delegatecall(msg.data)) 
           revert();
    }

}
