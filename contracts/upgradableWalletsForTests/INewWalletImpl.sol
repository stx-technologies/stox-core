pragma solidity ^0.4.18;
import "../token/IERC20Token.sol";
import "../predictions/PoolPrediction.sol";

contract INewWalletImpl {
    function transferToUserWithdrawalAccount(IERC20Token _token, uint _amount, IERC20Token _feesToken, uint _fee) public;
    function setUserWithdrawalAccount(address _userWithdrawalAccount) public;
    function voteOnPoolPrediction(PoolPrediction _prediction, uint _outcome, uint _amount) public;
    function approveBuy(IERC20Token _token, address _prediction, uint _amount) public;

    event SetRelayDispatcher(address _relayDispatcher);
    event TransferToBackupAccount(address _token, address _backupAccount, uint _amount);
    event TransferToUserWithdrawalAccount(address _token, address _userWithdrawalAccount, uint _amount, address _feesToken, address _feesAccount, uint _fee);
    event SetUserWithdrawalAccount(address _userWithdrawalAccount);

}