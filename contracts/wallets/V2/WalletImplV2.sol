pragma solidity ^0.4.23;
import "../../token/IERC20Token.sol";
import "../upgradable/UpgradableSmartWalletLib.sol";
import "./IWalletImplV2.sol";
import "../../predictions/types/scalar/ScalarPrediction.sol";
import "../../predictions/methods/IPredictionMethods.sol";
import "../../predictions/types/pool/PoolPrediction.sol";

/*
    @title WalletImpls contract - A wallet implementation. This specific one implements voting on a 
    scalar prediction. 
*/
contract WalletImplV2 is IWalletImplV2 {
        
    /*
     *  Members
     */
    using UpgradableSmartWalletLib for UpgradableSmartWalletLib.Wallet;
    UpgradableSmartWalletLib.Wallet public wallet;
   
    string constant VERSION = "0.1";
   

    /*
     *  Modifiers
     */
    modifier validAddress(address _address) {
        require(_address != 0x0);
        _;
    }

    modifier addressNotSet(address _address) {
        require(_address == 0);
        _;
    }

    modifier operatorOnly {
        require(msg.sender == wallet.operatorAccount);
        _;
    }

    /*
     *  Events
     */
    event TransferToUserWithdrawalAccount(address _token, 
                                            address _userWithdrawalAccount, 
                                            uint _amount, 
                                            address _feesToken, 
                                            address _feesAccount, 
                                            uint _fee);
    event SetUserWithdrawalAccount(address _userWithdrawalAccount);
    event VoteOnScalarPrediction(address _voter, address _prediction, int _outcome, uint _amount);
    event WithdrawFromPrediction(address _wallet, address _prediction);
    event GetPoolPredictionRefund(address _prediction, bytes32 _outcome);
    event GetScalarPredictionRefund(address _prediction, int _outcome);
        
    /*
        @dev Setting the account of the user to send funds to. 
        
        @param _userWithdrawalAccount       The user account to withdraw funds to
    */
    function setUserWithdrawalAccount(address _userWithdrawalAccount) 
        public
        operatorOnly
        validAddress(_userWithdrawalAccount)
        addressNotSet(wallet.userWithdrawalAccount) 
        {
            wallet.userWithdrawalAccount = _userWithdrawalAccount;
            emit SetUserWithdrawalAccount(_userWithdrawalAccount);
    }

    /*
        @dev Withdraw funds to the user account. 

        @param _token               The ERC20 token the owner withdraws from 
        @param _amount              Amount to transfer
        @param _feesToken           The ERC20 token for fee payment   
        @param _fee                 Fee to transfer   
    */
    function transferToUserWithdrawalAccount(IERC20Token _token, uint _amount, IERC20Token _feesToken, uint _fee) 
        public 
        operatorOnly
        validAddress(wallet.userWithdrawalAccount)
        {

            if (_fee > 0) {        
               _feesToken.transfer(wallet.feesAccount, _fee); 
            }       
                
            _token.transfer(wallet.userWithdrawalAccount, _amount);
            emit TransferToUserWithdrawalAccount(_token, 
                                                wallet.userWithdrawalAccount, 
                                                _amount,  
                                                _feesToken, 
                                                wallet.feesAccount, 
                                                _fee);   
    }

    /*
        @dev Vote on a prediction of type Pool

        @param _prediction       Pool prediction to vote on  
        @param _outcome          The chosen outcome to vote on
        @param _amount           Amount of tokens to vote on the outcome   
    */
    function voteOnScalarPrediction(IERC20Token _token, ScalarPrediction _prediction, int _outcome, uint _amount) 
        public
        validAddress(_prediction) 
        {
            _token.approve(_prediction, 0);
            _token.approve(_prediction, _amount);
            _prediction.placeTokens(_amount, _outcome);
            emit VoteOnScalarPrediction(msg.sender, _prediction, _outcome, _amount);
        }

    /*
        @dev Generic function for withdraw funds from a prediction

        @param _prediction       An interface for the prediction to withdraw from  
    */
    function withdrawFromPrediction(IPredictionMethods _prediction)
        public
        validAddress(_prediction)
        {
            _prediction.withdrawPrize();
            emit WithdrawFromPrediction(msg.sender, _prediction);
        }

    /*
        @dev Get a refund from a scalar prediction, after it is canceled

        @param _prediction       The scalar prediction
        @param _outcome          The outcome  
    */
    function getScalarPredictionRefund(ScalarPrediction _prediction, int _outcome)
        public
        validAddress(_prediction)
        {
            _prediction.getRefund(_outcome);
             emit GetScalarPredictionRefund(_prediction, _outcome);
        }
    
    /*
        @dev Get a refund from a pool prediction, after it is canceled

        @param _prediction       The pool prediction
        @param _outcome          The outcome  
    */
    function getPoolPredictionRefund(PoolPrediction _prediction, bytes32 _outcome)
        public
        validAddress(_prediction)
        {
            _prediction.getRefund(_outcome);
            emit GetPoolPredictionRefund(_prediction, _outcome);
        }
    /*
        @dev Test return value for a fallback function
    */
    function testReturnValue() public returns(uint) {
        return 100;
    }
    
}

