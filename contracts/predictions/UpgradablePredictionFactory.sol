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

    address relayDispatcher;
    address newCreatedPredictionAddress; 
    //address public factory;
    
    function UpgradablePredictionFactory(address _relayDispatcher /*, address _factory*/) 
        public 
        Ownable(msg.sender) 
        {
            relayDispatcher = _relayDispatcher;
            //factory = _factory;
    }
    /*
    function setFactory(address _factory) public ownerOnly {
        require ((address(_factory) != address(this)) && (address(_factory) != 0x0));

        factory = _factory;
    }
    */
    /*
        @dev Fallback function to delegate calls to the relay contract

    */
    function() {
        PredictionFactoryRelayDispatcher factoryRelayDispatcher = PredictionFactoryRelayDispatcher(relayDispatcher); 
        address relay = factoryRelayDispatcher.getPredictionFactoryImplAddress();
        
        if (!relay.delegatecall(msg.data)) 
           revert();
    }

}
