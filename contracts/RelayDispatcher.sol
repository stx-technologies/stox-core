pragma solidity ^0.4.18;

contract RelayDispatcher {
    
    /*
     *  Members
     */
    address public relayContract;
    address public operator;

    /*
     *  Modifiers
     */
    modifier validAddress(address _address) {
        require(_address != 0x0);
        _;
    }

    modifier operatorOnly() {
        require(msg.sender == operator);
        _;
    }

    /*
     *  Events
     */
    event SetRelayContractAddress(address _relayContract);

    /*
        @dev Initialize the RelayVersion contract
        
        @param _operator                    The contract operator address
        @param _relayVersion                Address of the contract to delegate function calls to
        
    */
    function RelayDispatcher(address _operator, address _relayContract) 
        public
        validAddress(_relayContract)
        validAddress(_operator) 
        {
            operator = _operator;
            relayContract = _relayContract;
    }

    /*
        @dev set the Relay contract address
        
        @param _relayVersion                Address of the contract to delegate function calls to
        
    */
    function setRelayContractAddress(address _relayContract) 
        public
        operatorOnly()
        {
            relayContract = _relayContract;
            SetRelayContractAddress(_relayContract);
    }
    
    /*
        @dev get the Relay contract address
        
               
    */
    function getRelayContractAddress()
        public
        returns (address val)
        {
            val = relayContract;
    }
    
}