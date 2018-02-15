pragma solidity ^0.4.18;
import "../Ownable.sol";
import "../RelayDispatcher.sol";

/*
    @title UpgradablePredictionFactory contract - A factory contract for generating predictions.
    It delegates the createPrediction() calls to the up-to-date prediction creation contract (address dispatched dynamically).
 */
contract UpgradablePredictionFactory is Ownable {

    /*
     * Members
     */

    address relayDispatcher; 
    
    function UpgradablePredictionFactory(address _relayDispatcher) 
        public 
        Ownable(msg.sender) 
        {
            relayDispatcher = _relayDispatcher;
    }
    
    /*
        @dev Fallback function to delegate calls to the relay contract

    */
    function() {
        RelayDispatcher currentRelayVersionContract = RelayDispatcher(relayDispatcher); 
        var currentRelayVersionAddress = currentRelayVersionContract.getRelayContractAddress();
        
        if (!currentRelayVersionAddress.delegatecall(msg.data)) 
           revert();
    }

}
