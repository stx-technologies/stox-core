pragma solidity ^0.4.18;
import "../../token/IERC20Token.sol";
import "../../predictions/types/pool/PoolPrediction.sol";

/*
    @title IWalletImpl contract - An interface contract for a wallet implementation.
*/
contract IWalletImpl {
    function transferToUserWithdrawalAccount(IERC20Token _token, uint _amount, IERC20Token _feesToken, uint _fee) public;
    function setUserWithdrawalAccount(address _userWithdrawalAccount) public;
    function voteOnPoolPrediction(IERC20Token _token, PoolPrediction _prediction, bytes32 _outcome, uint _amount) public;
    function withdrawFromPoolPrediction(PoolPrediction _prediction) public;
    //function approveBuy(IERC20Token _token, address _prediction, uint256 _amount) public {}

    event SetRelayDispatcher(address _relayDispatcher);
    event TransferToBackupAccount(address _token, address _backupAccount, uint _amount);
    event TransferToUserWithdrawalAccount(address _token, 
                                            address _userWithdrawalAccount, 
                                            uint _amount, 
                                            address _feesToken, 
                                            address _feesAccount, 
                                            uint _fee);
    event SetUserWithdrawalAccount(address _userWithdrawalAccount);
    event VoteOnPoolPrediction(address _voter, address _prediction, bytes32 _outcome, uint _amount);
    event WithdrawFromPoolPrediction(address _wallet, address _prediction);


}
