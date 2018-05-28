pragma solidity ^0.4.23;
import "./UpgradableSmartWalletLib.sol";
import "./RelayDispatcher.sol";
import "../../token/IERC20Token.sol";

/*
    @title UpgradableSmartWallet contract - An upgradable smart wallet implemenation. Calls to the wallet implementation
    are delegated through the set Relay Dispatcher
 */
contract UpgradableSmartWallet {

    /*
     *  Members
     */
    using UpgradableSmartWalletLib for UpgradableSmartWalletLib.Wallet;
    UpgradableSmartWalletLib.Wallet public wallet;

    /*
        @dev Initialize the contract

        @param _backupAccount               Operator account to release funds in case the user lost his withdrawal account
        @param _operator                    The operator account
        @param _feesAccount                 The account to transfer fees to
        @param _relayDispatcher             The address of the contract that holds the relay dispatcher
          
    */  
    constructor(address _backupAccount, address _operator, address _feesAccount, address _relayDispatcher) 
        public 
        {
            wallet.initUpgradableSmartWallet(_backupAccount, _operator, _feesAccount, _relayDispatcher);
    }

    /*
        @dev Withdraw funds to a backup account. 


        @param _token               The ERC20 token the owner withdraws from 
        @param _amount              Amount to transfer    
    */
    function transferToBackupAccount(IERC20Token _token, uint _amount) public {
        wallet.transferToBackupAccount(_token, _amount);
    }

    /*
        @dev Set a new RelayDispatcher address

        @param _relayDispatcher               RelayDispatcher new address
    */
    function setRelayDispatcher(address _relayDispatcher) public {
        wallet.setRelayDispatcher(_relayDispatcher);
    }

    /*
        @dev Fallback function to delegate calls to the relay contract

    */
    function() public {
        RelayDispatcher relayDispatcher = RelayDispatcher(wallet.relayDispatcher); 
        address relay = relayDispatcher.getSmartWalletImplAddress();
        
        assembly {
            calldatacopy(0x0, 0x0, calldatasize)
            //Using 32 as the default maximum return data size, 
            //assuming a non varying size of return value for all delegated functions 
            let result := delegatecall(gas, relay, 0x0, calldatasize, 0x0, 32)
            returndatacopy(0x0, 0x0, returndatasize)
            switch result case 0 {revert(0, 0)} default {return (0, returndatasize)}
        }
    }
}
