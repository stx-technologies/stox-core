pragma solidity ^0.4.18;
import "../token/IERC20Token.sol";
import "../upgradableWalletsForTests/RelayDispatcher.sol";

library UpgradableSmartWalletLib {
    
    /*
     *  Structs
     */
    struct Wallet {
        address operatorAccount;
        address backupAccount;
        address userWithdrawalAccount;
        address feesAccount;
        address relayDispatcher;
    }

    /*
     *  Modifiers
     */
    modifier validAddress(address _address) {
        require(_address != 0x0);
        _;
    }

    modifier operatorOnly(address _operatorAccount) {
        require(msg.sender == _operatorAccount);
        _;
    }

    /*
     *  Events
     */
    event TransferToBackupAccount(address _token, address _backupAccount, uint _amount);
    event SetRelayDispatcher(address _relayDispatcher);
    
    /*
        @dev Initialize the upgradable wallet with the the address of the contract that holds the up-to-date relay address
        
        @param _self                   Wallet storage
        @param _backupAccount          Operator account to release funds in case the user lost his withdrawal account
        @param _operator               The operator account
        @param _feesAccount            The account to transfer fees to
        @param _relayDispatcher        The address of the contract that dispatches the SmartWalletImpl address
        
    */
    function initUpgradableSmartWallet(Wallet storage _self, address _backupAccount, address _operator, address _feesAccount, address _relayDispatcher) 
        public
        validAddress(_relayDispatcher)
        {
            _self.relayDispatcher = _relayDispatcher;
            RelayDispatcher relayDispatcher = RelayDispatcher(_self.relayDispatcher); 
            address relay = relayDispatcher.getSmartWalletImplAddress();
            
            if (!relay.delegatecall(bytes4(keccak256("initWallet(address,address,address)")), _backupAccount, _operator, _feesAccount)) {
                revert();
            }
    }

    /*
        @dev Withdraw funds to a backup account. 

        @param _self                Wallet storage
        @param _token               The ERC20 token the owner withdraws from 
        @param _amount              Amount to transfer    
    */
    function transferToBackupAccount(Wallet storage _self, IERC20Token _token, uint _amount) 
        public 
        operatorOnly(_self.operatorAccount)
        {
            _token.transfer(_self.backupAccount, _amount);
            TransferToBackupAccount(_token, _self.backupAccount, _amount); 
    }

    /*
        @dev Set the contract address to relay(delegate) fallback functions to 

        @param _self                          Wallet storage
        @param _relayDispatcher               The contract address to relay(delegate) fallback functions to  
    */
    function setRelayDispatcher(Wallet storage _self, address _relayDispatcher)
        public
        operatorOnly(_self.operatorAccount)
        validAddress(_relayDispatcher)
        {
            _self.relayDispatcher = _relayDispatcher;
            SetRelayDispatcher(_relayDispatcher);
    }
}
