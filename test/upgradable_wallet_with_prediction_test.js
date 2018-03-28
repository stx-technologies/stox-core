const utils = require('./helpers/utils');
const NewWalletImpl = artifacts.require("./wallets/V1/WalletImpl.sol");
const UpgradableSmartWallet = artifacts.require("./wallets/upgradable/UpgradableSmartWallet.sol");
const INewWalletImpl = artifacts.require("./wallets/V1/IWalletImpl.sol");
const RelayDispatcher = artifacts.require("./wallets/upgradable/RelayDispatcher.sol");
const ExtendedERC20Token = artifacts.require("./token/ExtendedERC20Token.sol");
const PoolPrediction = artifacts.require("./predictions/types/pool/PoolPrediction.sol");
const UpgradablePredictionFactory = artifacts.require("./predictions/factory/UpgradablePredictionFactory.sol");
const IUpgradablePredictionFactory = artifacts.require("./predictions/factory/IUpgradablePredictionFactory.sol");
const PoolPredictionFactoryImpl = artifacts.require("./predictions/factory/PoolPredictionFactoryImpl.sol");
const IPoolPredictionFactoryImpl = artifacts.require("./predictions/factory/IPoolPredictionFactoryImpl.sol");
const UpgradableOracleFactory = artifacts.require("./oracles/factory/UpgradableOracleFactory.sol");
const IUpgradableOracleFactoryImpl = artifacts.require("./oracles/factory/IUpgradableOracleFactoryImpl.sol");
const OracleFactoryImpl = artifacts.require("./oracles/factory/OracleFactoryImpl.sol");
const MultipleOutcomeOracle = artifacts.require("./oracles/types/MultipleOutcomeOracle.sol");


let stoxTestToken;

//Prediction variables
let predictionFactory;
let upgradablePredictionFactory;
let iPoolPredictionFactoryImpl;
let poolPredictionFactoryImpl;
let upgradableOracleFactory;
let iUpgradableOracleFactoryImpl;
let oracleFactoryImpl;
let oracle;

//Wallet variables
let walletRelayDispatcher;
let upgradableSmartWallet;
let newWalletImpl;
let newWalletImplAddress;
let player1UpgradableWallet;
let iPlayer1UpgradableSmartWallet;
let player2UpgradableWallet;
let iPlayer2UpgradableSmartWallet;

//Accounts
let player1Account;
let player2Account;
let backupAccount;
let feesAccount;

function isEventArgValid(arg_value, expected_value){
    return (arg_value == expected_value);
}

function getLog(result, name, logIndex = 0) {
    return result.logs[logIndex][name];
}

function getLogArg(result, arg, logIndex = 0) {
    return result.logs[logIndex].args[arg];
}

contract ('UpgradableWalletWithPredictionTest', function(accounts) {
    let backupAccount             = accounts[0];
    let feesAccount               = accounts[1];
    let factoryOperator           = accounts[2];
    let oracleOperator            = accounts[3];
    let predictionOperator        = accounts[4];
    let walletsOperator           = accounts[5];
    let player1Account            = accounts[6];
    let player2Account            = accounts[7];
    let player3Account            = accounts[8];

    let tommorowInSeconds;
    let nowInSeconds;

    let calculationType = {
        breakEven:0,
        relative:1,
    };

    async function initOracle() {
        await iUpgradableOracleFactoryImpl.createMultipleOutcomeOracle("Test Oracle", {from: oracleOperator}).then(function(result) {
            oracle = MultipleOutcomeOracle.at(getLogArg(result, "_newOracle"));
        });
    }

    async function initPredictionInfra() {
        
        oracleFactoryImpl = await OracleFactoryImpl.new()
        upgradableOracleFactory = await UpgradableOracleFactory.new(oracleFactoryImpl.address, {from: oracleOperator});
        iUpgradableOracleFactoryImpl = IUpgradableOracleFactoryImpl.at(upgradableOracleFactory.address, {from: oracleOperator});
        
        poolPredictionFactoryImpl = await PoolPredictionFactoryImpl.new();
        upgradablePredictionFactory = await UpgradablePredictionFactory.new(poolPredictionFactoryImpl.address, {from: predictionOperator});
        iPoolPredictionFactoryImpl = IPoolPredictionFactoryImpl.at(upgradablePredictionFactory.address, {from: predictionOperator});
        
        var tomorrow = new Date();
        tomorrow.setDate((new Date).getDate() + 1);
        tommorowInSeconds = Math.round(tomorrow.getTime() / 1000);
        nowInSeconds = Math.round((new Date()).getTime() / 1000);

        await initOracle();
      
    }

    async function initPrediction(calcType) {
        let poolPrediction;
        await iPoolPredictionFactoryImpl.createPoolPrediction(oracle.address, tommorowInSeconds, tommorowInSeconds, "Test Prediction", stoxTestToken.address, calcType, {from: predictionOperator}).then(function(result) {
            poolPrediction = PoolPrediction.at(getLogArg(result, "_newPrediction"));
        });
        
        return poolPrediction;
    }

    async function initPredictionWithOutcomes(calcType) {
        let poolPrediction = await initPrediction(calcType);

        await poolPrediction.addOutcome("o1", {from: predictionOperator});
        await poolPrediction.addOutcome("o2", {from: predictionOperator});
        await poolPrediction.addOutcome("o3", {from: predictionOperator});

        return poolPrediction;
    }

    async function initWallets() {
        
        newWalletImpl = await NewWalletImpl.new();
        walletRelayDispatcher = await RelayDispatcher.new(walletsOperator, newWalletImpl.address);

        player1UpgradableWallet = await UpgradableSmartWallet.new(backupAccount,walletsOperator, feesAccount, walletRelayDispatcher.address);
        player2UpgradableWallet = await UpgradableSmartWallet.new(backupAccount,walletsOperator, feesAccount, walletRelayDispatcher.address);
                
        iPlayer1UpgradableSmartWallet = INewWalletImpl.at(player1UpgradableWallet.address);
        iPlayer2UpgradableSmartWallet = INewWalletImpl.at(player2UpgradableWallet.address);

        await iPlayer1UpgradableSmartWallet.setUserWithdrawalAccount(player1Account,{from: walletsOperator});
        await iPlayer2UpgradableSmartWallet.setUserWithdrawalAccount(player2Account,{from: walletsOperator});
       
    }

    async function initTokens() {
        
        // Clear existing tokens
        let player1Tokens = await stoxTestToken.balanceOf.call(player1Account);
        let player2Tokens = await stoxTestToken.balanceOf.call(player2Account);
        let backupAccountTokens = await stoxTestToken.balanceOf.call(backupAccount);
        let feesAccountTokens = await stoxTestToken.balanceOf.call(feesAccount);
        let player1UpgradableWalletTokens = await stoxTestToken.balanceOf.call(player1UpgradableWallet.address);
        let player2UpgradableWalletTokens = await stoxTestToken.balanceOf.call(player2UpgradableWallet.address);
        
        await stoxTestToken.destroy(player1Account, player1Tokens);
        await stoxTestToken.destroy(player2Account, player2Tokens);
        await stoxTestToken.destroy(backupAccount, backupAccountTokens);
        await stoxTestToken.destroy(feesAccount, feesAccountTokens);
        await stoxTestToken.destroy(player1UpgradableWallet.address, player1UpgradableWalletTokens);
        await stoxTestToken.destroy(player2UpgradableWallet.address, player2UpgradableWalletTokens);
        
        // Issue new tokens to Wallets
        await stoxTestToken.issue(player1UpgradableWallet.address, 1000);
        await stoxTestToken.issue(player2UpgradableWallet.address, 2000);
         
    }    

    before(async function() {
        // runs before all tests in this block
        stoxTestToken = await ExtendedERC20Token.new("Stox Text", "STX", 18);
        stoxTestToken.totalSupply = 10000;

        await initPredictionInfra();

      });
      
      it("Verify upgradable wallet vote on upgradable prediction outcome", async function() {
        await initWallets();
        await initTokens();
                
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});
 
        await iPlayer1UpgradableSmartWallet.voteOnPoolPrediction(stoxTestToken.address, poolPrediction.address, 1, 500);
        
        let predictionBalance = await stoxTestToken.balanceOf.call(poolPrediction.address);
        assert.equal(predictionBalance.toNumber(),500);
       
       });

       it("Verify vote on upgradable prediction outcome event fired", async function() {
        await initWallets();
        await initTokens();
                
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});
 
        tx_result = await iPlayer1UpgradableSmartWallet.voteOnPoolPrediction(stoxTestToken.address, poolPrediction.address, 1, 500);
        
        let event  = getLog(tx_result,"event")
        assert.equal(event,"VoteOnPoolPrediction")
  
       });

       it("Verify vote on upgradable prediction outcome event arguments correct", async function() {
        await initWallets();
        await initTokens();
                
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});
 
        tx_result = await iPlayer1UpgradableSmartWallet.voteOnPoolPrediction(stoxTestToken.address, poolPrediction.address, 1, 500);
        
        let event  = getLog(tx_result,"event")
        assert.equal(event,"VoteOnPoolPrediction")

        assert.equal(isEventArgValid(getLogArg(tx_result,"_prediction"),poolPrediction.address), true);
        assert.equal(isEventArgValid(getLogArg(tx_result,"_outcome"),1), true);
        assert.equal(isEventArgValid(getLogArg(tx_result,"_amount"),500), true);
  
       });
       
       it("verify that a user can withdraw funds from a unit", async function() {
        await initWallets();
        await initTokens();
               
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});
       
        await iPlayer1UpgradableSmartWallet.voteOnPoolPrediction(stoxTestToken.address, poolPrediction.address,1,1000); 
        await iPlayer2UpgradableSmartWallet.voteOnPoolPrediction(stoxTestToken.address, poolPrediction.address,2,2000);
        
        await poolPrediction.pause({from: predictionOperator});
        await poolPrediction.setUnitBuyingEndTime(nowInSeconds - 1000, {from: predictionOperator});
       
        await poolPrediction.publish({from: predictionOperator});
        await oracle.registerPrediction(poolPrediction.address, {from: oracleOperator});
        await oracle.setOutcome(poolPrediction.address, 1, {from: oracleOperator});

        await poolPrediction.resolve({from: predictionOperator});
        
        await iPlayer1UpgradableSmartWallet.withdrawFromPoolPrediction(poolPrediction.address);
        
        let player1UpgradableSmartWalletTokens = await stoxTestToken.balanceOf(player1UpgradableWallet.address);
        let tokenPool = await poolPrediction.tokenPool.call();
        let predictionTokens = await stoxTestToken.balanceOf.call(poolPrediction.address);
         
        assert.equal(player1UpgradableSmartWalletTokens, 3000);
        assert.equal(predictionTokens, 0);
        
        });

        it("verify withdraw funds from a unit event fired", async function() {
            await initWallets();
            await initTokens();
                   
            let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
            await poolPrediction.publish({from: predictionOperator});
           
            await iPlayer1UpgradableSmartWallet.voteOnPoolPrediction(stoxTestToken.address, poolPrediction.address,1,1000); 
            await iPlayer2UpgradableSmartWallet.voteOnPoolPrediction(stoxTestToken.address, poolPrediction.address,2,2000);
            
            await poolPrediction.pause({from: predictionOperator});
            await poolPrediction.setUnitBuyingEndTime(nowInSeconds - 1000, {from: predictionOperator});
           
            await poolPrediction.publish({from: predictionOperator});
            await oracle.registerPrediction(poolPrediction.address, {from: oracleOperator});
            await oracle.setOutcome(poolPrediction.address, 1, {from: oracleOperator});
    
            await poolPrediction.resolve({from: predictionOperator});
            
            tx_result =  await iPlayer1UpgradableSmartWallet.withdrawFromPoolPrediction(poolPrediction.address);

            let event  = getLog(tx_result,"event")
            assert.equal(event,"WithdrawFromPoolPrediction")
          
        });

        it("verify withdraw funds from a unit event arguments correct", async function() {
            await initWallets();
            await initTokens();
                   
            let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
            await poolPrediction.publish({from: predictionOperator});
           
            await iPlayer1UpgradableSmartWallet.voteOnPoolPrediction(stoxTestToken.address, poolPrediction.address,1,1000); 
            await iPlayer2UpgradableSmartWallet.voteOnPoolPrediction(stoxTestToken.address, poolPrediction.address,2,2000);
            
            await poolPrediction.pause({from: predictionOperator});
            await poolPrediction.setUnitBuyingEndTime(nowInSeconds - 1000, {from: predictionOperator});
           
            await poolPrediction.publish({from: predictionOperator});
            await oracle.registerPrediction(poolPrediction.address, {from: oracleOperator});
            await oracle.setOutcome(poolPrediction.address, 1, {from: oracleOperator});
    
            await poolPrediction.resolve({from: predictionOperator});
            
            tx_result =  await iPlayer1UpgradableSmartWallet.withdrawFromPoolPrediction(poolPrediction.address);

            let event  = getLog(tx_result,"event")
            assert.equal(event,"WithdrawFromPoolPrediction")

            assert.equal(isEventArgValid(getLogArg(tx_result,"_prediction"),poolPrediction.address), true);
          
        });
        
});