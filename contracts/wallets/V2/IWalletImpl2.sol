pragma solidity ^0.4.18;
import "../../token/IERC20Token.sol";
import "../../predictions/types/scalar/ScalarPrediction.sol";

/*
    @title IWalletImpl2 contract - An interface contract for a wallet implementation.
*/
contract IWalletImpl2 {
    function transferToUserWithdrawalAccount(IERC20Token _token, uint _amount, IERC20Token _feesToken, uint _fee) public;
    function setUserWithdrawalAccount(address _userWithdrawalAccount) public;
    function voteOnScalarPrediction(IERC20Token _token, ScalarPrediction _prediction, int _outcome, uint _amount) public;
    function withdrawFromScalarPrediction(ScalarPrediction _prediction) public;
    
    event SetRelayDispatcher(address _relayDispatcher);
    event TransferToBackupAccount(address _token, address _backupAccount, uint _amount);
    event TransferToUserWithdrawalAccount(address _token, 
                                            address _userWithdrawalAccount, 
                                            uint _amount, 
                                            address _feesToken, 
                                            address _feesAccount, 
                                            uint _fee);
    event SetUserWithdrawalAccount(address _userWithdrawalAccount);
    event VoteOnScalarPrediction(address _voter, address _prediction, int _outcome, uint _amount);
    event WithdrawFromScalarPrediction(address _wallet, address _prediction);
}
