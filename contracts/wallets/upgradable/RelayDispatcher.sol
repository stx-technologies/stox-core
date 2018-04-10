pragma solidity ^0.4.18;
import "../../Ownable.sol";

/*
    @title RelayDispatcher contract - A contract to hold the wallet implementation address to delegate calls to
 */
contract RelayDispatcher is Ownable {
    
    /*
     *  Members
     */
    address public smartWalletImplAddress;

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
    event SetSmartWalletImplAddress(address _smartWalletImplAddress);

    /*
        @dev Initialize the RelayDispatcher contract
        
        @param _owner                       The contract owner address
        @param _smartWalletImplAddress      Address of the contract to delegate function calls to
        
    */
    function RelayDispatcher(address _owner, address _smartWalletImplAddress) 
        public
        validAddress(_owner)
        validAddress(_smartWalletImplAddress)
        Ownable(_owner) 
        {
            smartWalletImplAddress = _smartWalletImplAddress;
    }

    /*
        @dev set the RelayDispatcher address
        
        @param _smartWalletImplAddress       Address of the contract to delegate function calls to
        
    */
    function setSmartWalletImplAddress(address _smartWalletImplAddress) 
        public
        validAddress(_smartWalletImplAddress)
        ownerOnly
        {
            smartWalletImplAddress = _smartWalletImplAddress;
            SetSmartWalletImplAddress(_smartWalletImplAddress);
    }
    
    /*
        @dev get the Relay contract address
             
    */
    function getSmartWalletImplAddress()
        public
        view
        returns (address)
        {
            return smartWalletImplAddress;
    }
}

