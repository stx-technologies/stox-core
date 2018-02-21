pragma solidity ^0.4.18;
import "../Ownable.sol";

contract PredictionFactoryRelayDispatcher is Ownable {
    
    /*
     *  Members
     */
    address public predictionFactoryImplAddress;
    address public operator;

    /*
     *  Modifiers
     */
    modifier validAddress(address _address) {
        require(_address != 0x0);
        _;
    }

    /*
     *  Events
     */
    event SetPredictionFactoryImplAddress(address _predictionFactoryImplAddress);

    /*
        @dev Initialize the PredictionFactoryRelayDispatcher contract
        
        @param _operator                            The contract operator address
        @param _predictionFactoryImplAddress        Address of the prediction factory to delegate function calls to
        
    */
    function PredictionFactoryRelayDispatcher(address _operator, address _predictionFactoryImplAddress) 
        public
        validAddress(_predictionFactoryImplAddress)
        validAddress(_operator)
        Ownable(_operator) 
        {
            //operator = _operator;
            predictionFactoryImplAddress = _predictionFactoryImplAddress;
    }

    /*
        @dev set the PredictionFactoryImpl address
        
        @param _predictionFactoryImplAddress         Address of the contract to delegate function calls to
        
    */
    function setPredictionFactoryImplAddress(address _predictionFactoryImplAddress) 
        public
        ownerOnly()
        {
            predictionFactoryImplAddress = _predictionFactoryImplAddress;
            SetPredictionFactoryImplAddress(_predictionFactoryImplAddress);
    }
    
    /*
        @dev get the Relay contract address
             
    */
    function getPredictionFactoryImplAddress()
        public
        returns (address)
        {
            return predictionFactoryImplAddress;
    }
    
}