const utils = require('./helpers/Utils');
const path = require('path');
const fs = require('fs');
const solc = require('solc');
const web3utils = require('web3-utils');

const ExtendedERC20Token = artifacts.require("./token/ExtendedERC20Token.sol");
const PoolPrediction = artifacts.require("./predictions/types/pool/PoolPrediction.sol");
const UpgradablePredictionFactory = artifacts.require("./predictions/factory/UpgradablePredictionFactory.sol");
const IPoolPredictionFactoryImpl = artifacts.require("./predictions/factory/IPoolPredictionFactoryImpl.sol");
const PoolPredictionFactoryImpl = artifacts.require("./predictions/factory/PoolPredictionFactoryImpl.sol");
const ScalarPredictionFactoryImpl = artifacts.require("./predictions/factory/ScalarPredictionFactoryImpl.sol");
const MultipleOutcomeOracle = artifacts.require("./oracles/types/MultipleOutcomeOracle.sol");
const UpgradableOracleFactory = artifacts.require("./oracles/factory/UpgradableOracleFactory.sol");
const IUpgradableOracleFactoryImpl = artifacts.require("./oracles/factory/IUpgradableOracleFactoryImpl.sol");
const OracleFactoryImpl = artifacts.require("./oracles/factory/OracleFactoryImpl.sol");

let stoxTestToken;
let predictionFactory;
let upgradablePredictionFactory;
let iPoolPredictionFactoryImpl;
let poolPredictionFactoryImpl;
let upgradableOracleFactory;
let iUpgradableOracleFactoryImpl;
let oracleFactoryImpl;
let oracle;

// Accounts
let predictionOperator;
let oracleOperator;
let player1;
let player2;
let player3;

function isEventArgValid(arg_value, expected_value){
    return (arg_value == expected_value);
}

function isEventNumberBytesArgValid(arg_value, expected_value){
    return (arg_value == web3utils.padRight(web3utils.numberToHex(expected_value),64));
}

function isEventStringBytesArgValid(arg_value, expected_value){
    return (arg_value == web3utils.padRight(web3utils.asciiToHex(expected_value),64));
}

function getLog(result, name, logIndex = 0) {
    return result.logs[logIndex][name];
}

function getLogArg(result, arg, logIndex = 0) {
    return result.logs[logIndex].args[arg];
}

function verifyUnit(unit, id, outcomeId, tokens, isWithdrawn, ownerAddress) {
    assert.equal(unit[0], id);
    assert.equal(unit[1], outcomeId);
    assert.equal(unit[2], tokens);
    assert.equal(unit[3], isWithdrawn);
    assert.equal(unit[4], ownerAddress);
}

contract('PoolPrediction', function(accounts) {

    let factoryOperator = accounts[0];
    let oracleOperator  = accounts[1];
    let predictionOperator   = accounts[2];
    let player1         = accounts[3];
    let player2         = accounts[4];
    let player3         = accounts[5];

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

    async function initPrediction(calcType) {
        let poolPrediction;
        await iPoolPredictionFactoryImpl.createPoolPrediction(oracle.address, tommorowInSeconds, tommorowInSeconds, "Test Prediction", stoxTestToken.address, calcType, {from: predictionOperator}).then(function(result) {
            poolPrediction = PoolPrediction.at(getLogArg(result, "_newPrediction"));
        });
        
        return poolPrediction;
    }

    async function initPredictionWithOutcomes(calcType) {
        let poolPrediction = await initPrediction(calcType);

        await poolPrediction.addOutcome(100, {from: predictionOperator});
        await poolPrediction.addOutcome(200, {from: predictionOperator});
        await poolPrediction.addOutcome("300", {from: predictionOperator});
        await poolPrediction.addOutcome("string", {from: predictionOperator});
        
        return poolPrediction;
    }

    async function initPlayers(predictionAddress) {
        // Clear existing players tokens
        let player1Tokens = await stoxTestToken.balanceOf.call(player1);
        let player2Tokens = await stoxTestToken.balanceOf.call(player2);
        let player3Tokens = await stoxTestToken.balanceOf.call(player3);

        await stoxTestToken.destroy(player1, player1Tokens);
        await stoxTestToken.destroy(player2, player2Tokens);
        await stoxTestToken.destroy(player3, player3Tokens);

        // Issue new tokens
        await stoxTestToken.issue(player1, 1000);
        await stoxTestToken.issue(player2, 2000);
        await stoxTestToken.issue(player3, 3000);

        // Allow prediction to use tokens so players can buy units
        await stoxTestToken.approve(predictionAddress, 0, {from: player1});
        await stoxTestToken.approve(predictionAddress, 0, {from: player2});
        await stoxTestToken.approve(predictionAddress, 0, {from: player3});
        
        await stoxTestToken.approve(predictionAddress, 1000, {from: player1});
        await stoxTestToken.approve(predictionAddress, 2000, {from: player2});
        await stoxTestToken.approve(predictionAddress, 3000, {from: player3});
    }

    async function checkGas() {
        var input = {
            'predictions/management/PredictionStatus.sol': fs.readFileSync('../stox-core/contracts/predictions/management/PredictionStatus.sol', 'utf8'),
            'predictions/management/PredictionMetaData.sol': fs.readFileSync('../stox-core/contracts/predictions/management/PredictionMetaData.sol', 'utf8'),
            'predictions/management/PredictionTiming.sol': fs.readFileSync('../stox-core/contracts/predictions/management/PredictionTiming.sol', 'utf8'),
            'predictions/types/pool/IPoolPredictionPrizeCalculation.sol': fs.readFileSync('../stox-core/contracts/predictions/types/pool/IPoolPredictionPrizeCalculation.sol', 'utf8'),
            'predictions/types/pool/IPoolPredictionPrizeDistribution.sol': fs.readFileSync('../stox-core/contracts/predictions/types/pool/IPoolPredictionPrizeDistribution.sol', 'utf8'),
            'predictions/types/pool/PoolPrediction.sol': fs.readFileSync('../stox-core/contracts/predictions/types/pool/PoolPrediction.sol', 'utf8'),
            'predictions/types/pool/PoolPredictionCalculationMethods.sol': fs.readFileSync('../stox-core/contracts/predictions/types/pool/PoolPredictionCalculationMethods.sol', 'utf8'),
            'predictions/types/pool/PoolPredictionPrizeCalculation.sol': fs.readFileSync('../stox-core/contracts/predictions/types/pool/PoolPredictionPrizeCalculation.sol', 'utf8'),
            'predictions/types/scalar/ScalarPredictionCalculationMethods.sol': fs.readFileSync('../stox-core/contracts/predictions/types/scalar/ScalarPredictionCalculationMethods.sol', 'utf8'),
            'predictions/types/pool/PoolPredictionPrizeDistribution.sol': fs.readFileSync('../stox-core/contracts/predictions/types/pool/PoolPredictionPrizeDistribution.sol', 'utf8'),
            'predictions/factory/IUpgradablePredictionFactory.sol': fs.readFileSync('../stox-core/contracts/predictions/factory/IUpgradablePredictionFactory.sol', 'utf8'),
            'predictions/factory/UpgradablePredictionFactory.sol': fs.readFileSync('../stox-core/contracts/predictions/factory/UpgradablePredictionFactory.sol', 'utf8'),
            'oracles/types/MultipleOutcomeOracle.sol': fs.readFileSync('../stox-core/contracts/oracles/types/MultipleOutcomeOracle.sol', 'utf8'),
            'token/IERC20Token.sol': fs.readFileSync('../stox-core/contracts/token/IERC20Token.sol', 'utf8'),
            'Ownable.sol': fs.readFileSync('../stox-core/contracts/Ownable.sol', 'utf8'),
            'Utils.sol': fs.readFileSync('../stox-core/contracts/Utils.sol', 'utf8'),
            'predictions/factory/PoolPredictionFactoryImpl.sol': fs.readFileSync('../stox-core/contracts/predictions/factory/PoolPredictionFactoryImpl.sol', 'utf8'),
            'predictions/factory/IPoolPredictionFactoryImpl.sol': fs.readFileSync('../stox-core/contracts/predictions/factory/IPoolPredictionFactoryImpl.sol', 'utf8')
            };
        
            // Compile the source code
        let output = await solc.compile({sources: input}, 1);
        
        let abi = await output.contracts['predictions/factory/UpgradablePredictionFactory.sol:UpgradablePredictionFactory'].interface;
        let bytecode = await '0x' + output.contracts['predictions/factory/UpgradablePredictionFactory.sol:UpgradablePredictionFactory'].bytecode;
        let deployed = await web3.eth.contract(JSON.parse(abi));
        let contractData = await deployed.new.getData({data: bytecode});
        let gasEstimate = await web3.eth.estimateGas({data: contractData});

        console.log("UpgradablePredictionFactory gas: " + gasEstimate); 

        let poolAbi = await output.contracts['predictions/factory/PoolPredictionFactoryImpl.sol:PoolPredictionFactoryImpl'].interface;
        let poolBytecode = await '0x' + output.contracts['predictions/factory/PoolPredictionFactoryImpl.sol:PoolPredictionFactoryImpl'].bytecode;
        let poolDeployed = await web3.eth.contract(JSON.parse(poolAbi));
        let poolContractData = await poolDeployed.new.getData({data: poolBytecode});
        let poolGasEstimate = await web3.eth.estimateGas({data: poolContractData});
        console.log("PoolPredictionFactoryImpl gas: " + poolGasEstimate); 
        
        let createPoolPrediction_gasEstimate = await iPoolPredictionFactoryImpl.createPoolPrediction.estimateGas(oracle.address, tommorowInSeconds, tommorowInSeconds, "Test Prediction", stoxTestToken.address, calculationType.relative, {from: predictionOperator});
        console.log("CreatePoolPrediction gas: " + createPoolPrediction_gasEstimate);

        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});
        await initPlayers(poolPrediction.address);
        let placeTokens_gasEstimate =  await poolPrediction.placeTokens.estimateGas(1000, 100, {from: player1});
        console.log("Place tokens on pool prediction outcome gas: " + placeTokens_gasEstimate);

    }

    before(async function() {
        // runs before all tests in this block
        stoxTestToken = await ExtendedERC20Token.new("Stox Text", "STX", 18);
        
        oracleFactoryImpl = await OracleFactoryImpl.new();
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
        
        await checkGas();
        
      });
    
    it("should throw if prediction name is invalid", async function() {
        await iPoolPredictionFactoryImpl.createPoolPrediction(oracle.address, tommorowInSeconds, tommorowInSeconds, "Test Prediction", stoxTestToken.address, calculationType.relative, {from: predictionOperator}).then(function(result) {
            poolPrediction = PoolPrediction.at(getLogArg(result, "_newPrediction"));
        });
                        
        let name = await poolPrediction.name.call();

        assert.equal(name, "Test Prediction");
    });
    
    it("should throw if oracle address is invalid", async function() {
        try {
            await iPoolPredictionFactoryImpl.createPoolPrediction(0, tommorowInSeconds, tommorowInSeconds, "Test Prediction", stoxTestToken.address, calculationType.relative, {from: predictionOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if prediction end time is invalid", async function() {
        try {
            await iPoolPredictionFactoryImpl.createPoolPrediction(oracle.address, 0, tommorowInSeconds, "Test Prediction", stoxTestToken.address, calculationType.relative, {from: predictionOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });
     
    it("should throw if units buying end time is invalid", async function() {
        try {
            await iPoolPredictionFactoryImpl.createPoolPrediction(oracle.address, tommorowInSeconds, 0, "Test Prediction", stoxTestToken.address, calculationType.relative, {from: predictionOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if prediction end time < units buying end time", async function() {
        try {
            await iPoolPredictionFactoryImpl.createPoolPrediction(oracle.address, tommorowInSeconds, (tommorowInSeconds + 1000), "Test Prediction", stoxTestToken.address, calculationType.relative, {from: predictionOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if outcome name is invalid", async function() {
        let poolPrediction = await initPrediction(calculationType.relative);
        
        try {
            await poolPrediction.addOutcome("", {from: predictionOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });
    
    it("should throw if a non owner added outcome", async function() {
        let poolPrediction = await initPrediction(calculationType.relative);

        try {
            await poolPrediction.addOutcome("outcome1", {from: player1});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });
    
    it("should throw if prediction is published without outcomes", async function() {
        let poolPrediction = await initPrediction(calculationType.relative);

        try {
            await poolPrediction.publish({from: predictionOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if prediction is published with 1 outcome", async function() {
        let poolPrediction = await initPrediction(calculationType.relative);

        await poolPrediction.addOutcome("outcome1", {from: predictionOperator});
        try {
            await poolPrediction.publish({from: predictionOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if a non owner publish the prediction", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);

        try {
            await poolPrediction.publish({from: player1});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("verify that the owner published the prediction", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);

        await poolPrediction.publish({from: predictionOperator});
        let predictionStatus = await poolPrediction.status.call();
        assert.equal(predictionStatus, 1);
    });

    it("should throw if an already published prediction is published", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});

        try {
            await poolPrediction.publish({from: predictionOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if a canceled prediction is published", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});
        await poolPrediction.cancel({from: predictionOperator});

        try {
            await poolPrediction.publish({from: predictionOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("verify that a paused prediction can be published", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});
        await poolPrediction.pause({from: predictionOperator});
        let predictionStatus = await poolPrediction.status.call();
        assert.equal(predictionStatus, 3);

        await poolPrediction.publish({from: predictionOperator});
        predictionStatus = await poolPrediction.status.call();
        assert.equal(predictionStatus, 1);
    });

    it("verify that the units buying end time can be changed when prediction is initializing", async function() {
        let poolPrediction = await initPrediction(calculationType.relative);

        await poolPrediction.setUnitBuyingEndTime(tommorowInSeconds - 1000, {from: predictionOperator});
        let unitBuyingEndTimeSeconds = await poolPrediction.unitBuyingEndTimeSeconds.call();
        assert.equal(unitBuyingEndTimeSeconds, tommorowInSeconds - 1000);
    });

    it("verify that the units buying end time can be changed when prediction is paused", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});
        await poolPrediction.pause({from: predictionOperator});

        await poolPrediction.setUnitBuyingEndTime(tommorowInSeconds - 1000, {from: predictionOperator});
        let unitBuyingEndTimeSeconds = await poolPrediction.unitBuyingEndTimeSeconds.call();
        assert.equal(unitBuyingEndTimeSeconds, tommorowInSeconds - 1000);
    });

    it("should throw if units buying end time is changed when prediction is published", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});

        try {
            await poolPrediction.setUnitBuyingEndTime(tommorowInSeconds - 1000, {from: predictionOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if a non owner changes units buying end time", async function() {
        let poolPrediction = await initPrediction(calculationType.relative);

        try {
            await poolPrediction.setUnitBuyingEndTime(tommorowInSeconds - 1000, {from: player1});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("verify that the prediction end time can be changed when prediction is initializing", async function() {
        let poolPrediction = await initPrediction(calculationType.relative);

        await poolPrediction.setPredictionEndTime(tommorowInSeconds + 1000, {from: predictionOperator});
        let predictionEndTimeSeconds = await poolPrediction.predictionEndTimeSeconds.call();
        assert.equal(predictionEndTimeSeconds, tommorowInSeconds + 1000);
    });

    it("verify that the prediction end time can be changed when prediction is paused", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});
        await poolPrediction.pause({from: predictionOperator});

        await poolPrediction.setPredictionEndTime(tommorowInSeconds + 1000, {from: predictionOperator});
        let predictionEndTimeSeconds = await poolPrediction.predictionEndTimeSeconds.call();
        assert.equal(predictionEndTimeSeconds, tommorowInSeconds + 1000);
    });

    it("should throw if a non owner changes prediction end time", async function() {
        let poolPrediction = await initPrediction(calculationType.relative);

        try {
            await poolPrediction.setPredictionEndTime(tommorowInSeconds + 1000, {from: player1});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("verify that the prediction name can be changed", async function() {
        let poolPrediction = await initPrediction(calculationType.relative);

        await poolPrediction.setPredictionName("new name", {from: predictionOperator});
        let predictionName = await poolPrediction.name.call();
        assert.equal(predictionName, "new name");
    });

    it("should throw if a non owner changes prediction name", async function() {
        let poolPrediction = await initPrediction(calculationType.relative);

        try {
            await poolPrediction.setPredictionName("new name", {from: player1});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("verify that the oracle can be changed", async function() {
        let poolPrediction = await initPrediction(calculationType.relative);
        let newOracle;

        await iUpgradableOracleFactoryImpl.createMultipleOutcomeOracle("Test Oracle", {from: oracleOperator}).then(function(result) {
            newOracle = MultipleOutcomeOracle.at(getLogArg(result, "_newOracle"));
        });    

        //await oracleFactory.createOracle("Test Oracle", {from: oracleOperator}).then(function(result) {
        //    newOracle = Oracle.at(getLogArg(result, "_oracle"));
        //});

        await poolPrediction.setOracle(newOracle.address, {from: predictionOperator});
        let oracleAddress = await poolPrediction.oracleAddress.call();
        assert.equal(oracleAddress, newOracle.address);
    });
    
    it("verify that a user can buy a unit", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});
        await initPlayers(poolPrediction.address);
        
        await poolPrediction.placeTokens(1000, 100, {from: player1});
        //let unit = await poolPrediction.units.call(0);
        //verifyUnit(unit, 1, 1, 1000, false, player1);

        let tokenPool = await poolPrediction.tokenPool.call();
        let predictionTokens = await stoxTestToken.balanceOf.call(poolPrediction.address);

        assert.equal(tokenPool, 1000);
        assert.equal(predictionTokens.toNumber(), 1000);
    });
    
    it("verify that multiple users can buy units", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});
        await initPlayers(poolPrediction.address);

        await poolPrediction.placeTokens(1000, 100, {from: player1});
        await poolPrediction.placeTokens(2000, 200, {from: player2});
        await poolPrediction.placeTokens(3000, 100, {from: player3});

        let tokenPool = await poolPrediction.tokenPool.call();
        let predictionTokens = await stoxTestToken.balanceOf.call(poolPrediction.address);

        assert.equal(tokenPool, 6000);
        assert.equal(predictionTokens, 6000);
    });
   
    it("should throw if trying to resolve an prediction before oracle has been set", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});
        await initPlayers(poolPrediction.address);
        await poolPrediction.placeTokens(1000, 100, {from: player1});
        await poolPrediction.placeTokens(2000, 200, {from: player2});
        await poolPrediction.placeTokens(3000, 100, {from: player3});

        await poolPrediction.pause({from: predictionOperator});
        await poolPrediction.setUnitBuyingEndTime(nowInSeconds - 1000, {from: predictionOperator});
        await poolPrediction.publish({from: predictionOperator});
        
        try {
            //await poolPrediction.resolve({from: predictionOperator});
            await poolPrediction.contract.resolve['']({from: predictionOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });
    
    it("should throw if trying to resolve an prediction before units buying time has ended", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});
        await initPlayers(poolPrediction.address);
        await poolPrediction.placeTokens(1000, 100, {from: player1});
        await poolPrediction.placeTokens(2000, "300", {from: player2});
        await poolPrediction.placeTokens(3000, 100, {from: player3});

        await oracle.registerPrediction(poolPrediction.address, {from: oracleOperator});
        await oracle.setOutcome(poolPrediction.address, 100, {from: oracleOperator});

        try {
            //await poolPrediction.resolve({from: predictionOperator});
            await poolPrediction.contract.resolve['']({from: predictionOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });
    
    it("verify that a prediction can be resolved", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});
        
        await initPlayers(poolPrediction.address);
        await poolPrediction.placeTokens(1000, 100, {from: player1});
        await poolPrediction.placeTokens(2000, 200, {from: player2});
        await poolPrediction.placeTokens(3000, 100, {from: player3});

        await poolPrediction.pause({from: predictionOperator});
        await poolPrediction.setUnitBuyingEndTime(nowInSeconds - 1000, {from: predictionOperator});
        await poolPrediction.publish({from: predictionOperator});
        await oracle.registerPrediction(poolPrediction.address, {from: oracleOperator});
        await oracle.setOutcome(poolPrediction.address, 100, {from: oracleOperator});
        
         
        //await poolPrediction.resolve({from: predictionOperator});
        await poolPrediction.contract.resolve['']({from: predictionOperator});
        
        predictionStatus = await poolPrediction.status.call();
        assert.equal(predictionStatus, 2);

        let winnigOutcome = await poolPrediction.winningOutcome.call();
        assert.equal(isEventNumberBytesArgValid(winnigOutcome, 100),true);

        let player1Winnings = await poolPrediction.calculateUserWithdrawAmount(player1);
        let player2Winnings = await poolPrediction.calculateUserWithdrawAmount(player2);
        let player3Winnings = await poolPrediction.calculateUserWithdrawAmount(player3);

        assert.equal(player1Winnings, 1500);
        assert.equal(player2Winnings, 0);
        assert.equal(player3Winnings, 4500);
    });
    
    it("verify that a user can withdraw funds from a unit", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});
        
        await initPlayers(poolPrediction.address);
        await poolPrediction.placeTokens(1000, 100, {from: player1});
        await poolPrediction.placeTokens(2000, 200, {from: player2});
        await poolPrediction.placeTokens(3000, 100, {from: player3});

        await poolPrediction.pause({from: predictionOperator});
        await poolPrediction.setUnitBuyingEndTime(nowInSeconds - 1000, {from: predictionOperator});
        await poolPrediction.publish({from: predictionOperator});
        await oracle.registerPrediction(poolPrediction.address, {from: oracleOperator});
        await oracle.setOutcome(poolPrediction.address, 100, {from: oracleOperator});

        //await poolPrediction.resolve({from: predictionOperator});
        await poolPrediction.contract.resolve['']({from: predictionOperator});

        await poolPrediction.withdrawPrize({from: player1});

        let player1Tokens = await stoxTestToken.balanceOf(player1);
        let tokenPool = await poolPrediction.tokenPool.call();
        let predictionTokens = await stoxTestToken.balanceOf.call(poolPrediction.address);

        assert.equal(player1Tokens, 1500);
        assert.equal(predictionTokens, 4500);
    });

    it("verify that a user can withdraw funds from a winning outcome, break even method", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.breakEven);
        await poolPrediction.publish({from: predictionOperator});
        
        await initPlayers(poolPrediction.address);
        await poolPrediction.placeTokens(1000, 100, {from: player1});
        await poolPrediction.placeTokens(2000, 200, {from: player2});
        await poolPrediction.placeTokens(3000, 100, {from: player3});

        await poolPrediction.pause({from: predictionOperator});
        await poolPrediction.setUnitBuyingEndTime(nowInSeconds - 1000, {from: predictionOperator});
        await poolPrediction.publish({from: predictionOperator});
        await oracle.registerPrediction(poolPrediction.address, {from: oracleOperator});
        await oracle.setOutcome(poolPrediction.address, 100, {from: oracleOperator});

        //await poolPrediction.resolve({from: predictionOperator});
        await poolPrediction.contract.resolve['']({from: predictionOperator});

        await poolPrediction.withdrawPrize({from: player1});

        let player1Tokens = await stoxTestToken.balanceOf(player1);
        let tokenPool = await poolPrediction.tokenPool.call();
        let predictionTokens = await stoxTestToken.balanceOf.call(poolPrediction.address);

        assert.equal(player1Tokens, 1000);
        assert.equal(predictionTokens, 5000);
    });

    it("verify that a user can withdraw funds from multiple units", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});
        
        await initPlayers(poolPrediction.address);
        await poolPrediction.placeTokens(1000, 100, {from: player1});
        await poolPrediction.placeTokens(2000, 200, {from: player2});
        await poolPrediction.placeTokens(2000, 100, {from: player3});
        await poolPrediction.placeTokens(1000, 100, {from: player3});

        await poolPrediction.pause({from: predictionOperator});
        await poolPrediction.setUnitBuyingEndTime(nowInSeconds - 1000, {from: predictionOperator});
        await poolPrediction.publish({from: predictionOperator});
        await oracle.registerPrediction(poolPrediction.address, {from: oracleOperator});
        await oracle.setOutcome(poolPrediction.address, 100, {from: oracleOperator});

        //await poolPrediction.resolve({from: predictionOperator});
        await poolPrediction.contract.resolve['']({from: predictionOperator});

        await poolPrediction.withdrawPrize({from: player3});

        let player3Tokens = await stoxTestToken.balanceOf(player3);
        let tokenPool = await poolPrediction.tokenPool.call();
        let predictionTokens = await stoxTestToken.balanceOf.call(poolPrediction.address);

        assert.equal(player3Tokens, 4500);
        assert.equal(predictionTokens, 1500);
    });
    
    it("verify that the prediction can be canceled", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});
        await poolPrediction.cancel({from: predictionOperator});
        
        predictionStatus = await poolPrediction.status.call();
        assert.equal(predictionStatus, 4);
    });

    it("verify that a operator can refund a user after the prediction is canceled", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});

        await initPlayers(poolPrediction.address);
        await poolPrediction.placeTokens(1000, 100, {from: player1});
        await poolPrediction.placeTokens(2000, 200, {from: player2});
        await poolPrediction.placeTokens(3000, 100, {from: player3});

        await poolPrediction.cancel({from: predictionOperator});
        await poolPrediction.refundUser(player1, 100, {from: predictionOperator});

        let player1Tokens = await stoxTestToken.balanceOf(player1);
        let tokenPool = await poolPrediction.tokenPool.call();
        let predictionTokens = await stoxTestToken.balanceOf.call(poolPrediction.address);

        assert.equal(player1Tokens, 1000);
        assert.equal(tokenPool, 5000);
        assert.equal(predictionTokens, 5000);
    });

    it("verify that a user can get a refund after the prediction is canceled", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});

        await initPlayers(poolPrediction.address);
        await poolPrediction.placeTokens(1000, 100, {from: player1});
        await poolPrediction.placeTokens(2000, 200, {from: player2});
        await poolPrediction.placeTokens(3000, 100, {from: player3});

        await poolPrediction.cancel({from: predictionOperator});
        await poolPrediction.getRefund(100, {from: player1});

        let player1Tokens = await stoxTestToken.balanceOf(player1);
        let tokenPool = await poolPrediction.tokenPool.call();
        let predictionTokens = await stoxTestToken.balanceOf.call(poolPrediction.address);

        assert.equal(player1Tokens, 1000);
        assert.equal(tokenPool, 5000);
        assert.equal(predictionTokens, 5000);
    });
    
    it("verify that an prediction can be paused", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});
        await poolPrediction.pause({from: predictionOperator});
        
        predictionStatus = await poolPrediction.status.call();
        assert.equal(predictionStatus, 3);
    });
    

    it ("verify withdraw prize event fired", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});
        
        await initPlayers(poolPrediction.address);
        await poolPrediction.placeTokens(1000, 100, {from: player1});
        await poolPrediction.placeTokens(2000, 200, {from: player2});
        await poolPrediction.placeTokens(3000, 100, {from: player3});

        await poolPrediction.pause({from: predictionOperator});
        await poolPrediction.setUnitBuyingEndTime(nowInSeconds - 1000, {from: predictionOperator});
        await poolPrediction.publish({from: predictionOperator});
        await oracle.registerPrediction(poolPrediction.address, {from: oracleOperator});
        await oracle.setOutcome(poolPrediction.address, 100, {from: oracleOperator});

        //await poolPrediction.resolve({from: predictionOperator});
        await poolPrediction.contract.resolve['']({from: predictionOperator});

        tx_result = await poolPrediction.withdrawPrize({from: player1});

        let event  = getLog(tx_result,"event")
        assert.equal(event,"PrizeWithdrawn")
    });

    it ("verify place tokens event fired", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});
        
        await initPlayers(poolPrediction.address);
        tx_result = await poolPrediction.placeTokens(1000, 100, {from: player1});

        let event  = getLog(tx_result,"event")
        assert.equal(event,"TokensPlacedOnOutcome")

    });

    it("verify that a user can get a refund after the prediction is canceled", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});

        await initPlayers(poolPrediction.address);
        await poolPrediction.placeTokens(1000, 100, {from: player1});
        await poolPrediction.placeTokens(2000, 200, {from: player2});
        await poolPrediction.placeTokens(3000, 100, {from: player3});

        await poolPrediction.cancel({from: predictionOperator});
        tx_result = await poolPrediction.getRefund(100, {from: player1});

        let event  = getLog(tx_result,"event")
        assert.equal(event,"UserRefunded")
    });

    it("verify that the owner can add an outcome", async function() {
        let poolPrediction = await initPrediction(calculationType.relative);
        tx_result = await poolPrediction.addOutcome("outcome1", {from: predictionOperator});
        
        let event  = getLog(tx_result,"event")
        assert.equal(event,"OutcomeAdded")
    });
    
    it ("verify withdraw prize amount event argument correct", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});
        
        await initPlayers(poolPrediction.address);
        await poolPrediction.placeTokens(1000, 100, {from: player1});
        await poolPrediction.placeTokens(2000, 200, {from: player2});
        await poolPrediction.placeTokens(3000, 100, {from: player3});

        await poolPrediction.pause({from: predictionOperator});
        await poolPrediction.setUnitBuyingEndTime(nowInSeconds - 1000, {from: predictionOperator});
        await poolPrediction.publish({from: predictionOperator});
        await oracle.registerPrediction(poolPrediction.address, {from: oracleOperator});
        await oracle.setOutcome(poolPrediction.address, 100, {from: oracleOperator});
        
        await poolPrediction.contract.resolve['']({from: predictionOperator});
        //await poolPrediction.resolve({from: predictionOperator});
        
        tx_result = await poolPrediction.withdrawPrize({from: player1});

        let event  = getLog(tx_result,"event")
        assert.equal(event,"PrizeWithdrawn")

        assert.equal(isEventArgValid(getLogArg(tx_result,"_tokenAmount"),1500), true);
        
    });
    
    it ("verify place tokens amount and outcome event arguments correct", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});
        
        await initPlayers(poolPrediction.address);
        tx_result = await poolPrediction.placeTokens(1000, 100, {from: player1});

        let event  = getLog(tx_result,"event")
        assert.equal(event,"TokensPlacedOnOutcome")
        assert.equal(isEventArgValid(getLogArg(tx_result,"_tokenAmount"),1000), true);
        assert.equal(isEventNumberBytesArgValid(getLogArg(tx_result,"_outcome"),100), true);

    });

    it("verify refund event arguments correct", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});

        await initPlayers(poolPrediction.address);
        await poolPrediction.placeTokens(1000, 100, {from: player1});
        await poolPrediction.placeTokens(2000, 200, {from: player2});
        await poolPrediction.placeTokens(3000, 100, {from: player3});

        await poolPrediction.cancel({from: predictionOperator});
        tx_result = await poolPrediction.getRefund(100, {from: player1});

        let event  = getLog(tx_result,"event")
        assert.equal(event,"UserRefunded")

        assert.equal(isEventArgValid(getLogArg(tx_result,"_tokenAmount"),1000), true);
        assert.equal(isEventNumberBytesArgValid(getLogArg(tx_result,"_outcome"),100), true);
    });
    
    it("verify refund event number string argument correct", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});

        await initPlayers(poolPrediction.address);
        await poolPrediction.placeTokens(1000, '300', {from: player1});
        await poolPrediction.placeTokens(2000, 200, {from: player2});
        await poolPrediction.placeTokens(3000, '300', {from: player3});

        await poolPrediction.cancel({from: predictionOperator});
        tx_result = await poolPrediction.getRefund('300', {from: player1});

        let event  = getLog(tx_result,"event")
        assert.equal(event,"UserRefunded")
        assert.equal(isEventArgValid(getLogArg(tx_result,"_tokenAmount"),1000), true);
        //console.log(getLogArg(tx_result,"_outcome"));
        //console.log(web3utils.padRight(web3utils.asciiToHex('barca 300'),64));
        assert.equal(isEventNumberBytesArgValid(getLogArg(tx_result,"_outcome"),'300'), true);
    });

    it("verify refund event pure string argument correct", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});

        await initPlayers(poolPrediction.address);
        await poolPrediction.placeTokens(1000, 'string', {from: player1});
        await poolPrediction.placeTokens(2000, 200, {from: player2});
        await poolPrediction.placeTokens(3000, 'string', {from: player3});

        await poolPrediction.cancel({from: predictionOperator});
        tx_result = await poolPrediction.getRefund('string', {from: player1});

        let event  = getLog(tx_result,"event")
        assert.equal(event,"UserRefunded")
        assert.equal(isEventArgValid(getLogArg(tx_result,"_tokenAmount"),1000), true);
        assert.equal(isEventStringBytesArgValid(getLogArg(tx_result,"_outcome"),'string'), true);
    });
    
    it("should throw if trying to add an empty outcome", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});

        await initPlayers(poolPrediction.address);
        
        try {
            await poolPrediction.addOutcome("",{from: predictionOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if trying to place tokens on an outcome that doesnt exist", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});

        await initPlayers(poolPrediction.address);
        
        try {
            await poolPrediction.placeTokens(1000, 'non existant outcome', {from: player1});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });
    
    it("verify vote on an outcome with special chars", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        
        await initPlayers(poolPrediction.address);
        await poolPrediction.addOutcome("string!@~#$%^&*()_+",{from: predictionOperator});
        await poolPrediction.publish({from: predictionOperator});
                
        tx_result = await poolPrediction.placeTokens(1000, "string!@~#$%^&*()_+", {from: player1});
        
        let event  = getLog(tx_result,"event")
        assert.equal(event,"TokensPlacedOnOutcome")
        assert.equal(isEventArgValid(getLogArg(tx_result,"_tokenAmount"),1000), true);
        assert.equal(isEventStringBytesArgValid(getLogArg(tx_result,"_outcome"),"string!@~#$%^&*()_+"), true);
        
    });
    

    it ("should throw if non existing outcome is resolved, after being set by the Oracle", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});
        
        await initPlayers(poolPrediction.address);
        await poolPrediction.placeTokens(1000, 100, {from: player1});
        
        await poolPrediction.pause({from: predictionOperator});
        await poolPrediction.setUnitBuyingEndTime(nowInSeconds - 1000, {from: predictionOperator});
        await poolPrediction.publish({from: predictionOperator});
        await oracle.registerPrediction(poolPrediction.address, {from: oracleOperator});
        await oracle.setOutcome(poolPrediction.address, 1000, {from: oracleOperator});

        try {
            await poolPrediction.contract.resolve['']({from: predictionOperator});
        }  catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
        
    });
    

    it("verify that a user cannot withdraw funds from an un resolved prediction", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});
        
        await initPlayers(poolPrediction.address);
        await poolPrediction.placeTokens(1000, 100, {from: player1});
        await poolPrediction.placeTokens(2000, 200, {from: player2});
        
        await poolPrediction.pause({from: predictionOperator});
        await poolPrediction.setUnitBuyingEndTime(nowInSeconds - 1000, {from: predictionOperator});
        await poolPrediction.publish({from: predictionOperator});
        await oracle.registerPrediction(poolPrediction.address, {from: oracleOperator});
        await oracle.setOutcome(poolPrediction.address, 100, {from: oracleOperator});

        try {
             await poolPrediction.withdrawPrize({from: player1});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
      
    });

    
    it("verify that a relative prediction with 0 tokens on the winning outcome cannot be withdrawn", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});
        
        await initPlayers(poolPrediction.address);
        await poolPrediction.placeTokens(1000, 100, {from: player1});
        await poolPrediction.placeTokens(2000, 100, {from: player2});
        
        await poolPrediction.pause({from: predictionOperator});
        await poolPrediction.setUnitBuyingEndTime(nowInSeconds - 1000, {from: predictionOperator});
        await poolPrediction.publish({from: predictionOperator});
        await oracle.registerPrediction(poolPrediction.address, {from: oracleOperator});
        await oracle.setOutcome(poolPrediction.address, 200, {from: oracleOperator});
        await poolPrediction.contract.resolve['']({from: predictionOperator});

        try {
            await poolPrediction.withdrawPrize({from: player1});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
      
    });
    
    it("should throw if the operator tries to refund a user with 0 tokens on the outcome", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});

        await initPlayers(poolPrediction.address);
        await poolPrediction.placeTokens(1000, 100, {from: player1});
        await poolPrediction.cancel({from: predictionOperator});
        
        try {
            await poolPrediction.refundUser(player1, 200, {from: predictionOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });
    
    it("should throw if the user tries to get a refund with 0 tokens on the outcome", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});

        await initPlayers(poolPrediction.address);
        await poolPrediction.placeTokens(1000, 100, {from: player1});
        await poolPrediction.cancel({from: predictionOperator});
        
        try {
            await poolPrediction.getRefund(200, {from: player1});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });
    
    it("should throw if the user tries to get a refund twice on the same outcome", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});

        await initPlayers(poolPrediction.address);
        await poolPrediction.placeTokens(1000, 100, {from: player1});
        await poolPrediction.cancel({from: predictionOperator});
        await poolPrediction.getRefund(100, {from: player1});

        try {
            await poolPrediction.getRefund(100, {from: player1});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });
    
    it("should throw if a user tried to withdraw funds twice", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});
        
        await initPlayers(poolPrediction.address);
        await poolPrediction.placeTokens(1000, 100, {from: player1});
        await poolPrediction.placeTokens(2000, 200, {from: player2});
        await poolPrediction.placeTokens(3000, 100, {from: player3});

        await poolPrediction.pause({from: predictionOperator});
        await poolPrediction.setUnitBuyingEndTime(nowInSeconds - 1000, {from: predictionOperator});
        await poolPrediction.publish({from: predictionOperator});
        await oracle.registerPrediction(poolPrediction.address, {from: oracleOperator});
        await oracle.setOutcome(poolPrediction.address, 100, {from: oracleOperator});

        //await poolPrediction.resolve({from: predictionOperator});
        await poolPrediction.contract.resolve['']({from: predictionOperator});

        await poolPrediction.withdrawPrize({from: player1});

        try {
            await poolPrediction.withdrawPrize({from: player1});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });
    
    it("should throw if a user tries to place 0 tokens on an outcome", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});
        
        await initPlayers(poolPrediction.address);
        
        try {
            await poolPrediction.placeTokens(0, 100, {from: player1});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });
    

    it("should throw if an Oracle tries to set an outcome on an unregistered prediction", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});
        
        await initPlayers(poolPrediction.address);
        
        try {
            await oracle.setOutcome(poolPrediction.address, 100, {from: oracleOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });
    
    it("should throw if an Oracle tries to set an outcome on a registerd->unregistered prediction", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});
        
        await initPlayers(poolPrediction.address);
        await oracle.registerPrediction(poolPrediction.address, {from: oracleOperator});
        await oracle.unRegisterPrediction(poolPrediction.address, {from: oracleOperator});
        
        try {
            await oracle.setOutcome(poolPrediction.address, 100, {from: oracleOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });
    
    it("verify that a user cannot withdraw funds not having a winning outcome", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});
        
        await initPlayers(poolPrediction.address);
        await poolPrediction.placeTokens(1000, 100, {from: player1});
        await poolPrediction.placeTokens(2000, 200, {from: player2});
        
        await poolPrediction.pause({from: predictionOperator});
        await poolPrediction.setUnitBuyingEndTime(nowInSeconds - 1000, {from: predictionOperator});
        await poolPrediction.publish({from: predictionOperator});
        await oracle.registerPrediction(poolPrediction.address, {from: oracleOperator});
        await oracle.setOutcome(poolPrediction.address, "300", {from: oracleOperator});
        await poolPrediction.contract.resolve['']({from: predictionOperator});
        
        try {
            await poolPrediction.withdrawPrize({from: player1});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });
    
    it("verify that a user can withdraw funds, non-winning outcome, break even method", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.breakEven);
        await poolPrediction.publish({from: predictionOperator});
        
        await initPlayers(poolPrediction.address);
        await poolPrediction.placeTokens(1000, 100, {from: player1});
        await poolPrediction.placeTokens(2000, 200, {from: player2});
        await poolPrediction.placeTokens(3000, 100, {from: player3});

        await poolPrediction.pause({from: predictionOperator});
        await poolPrediction.setUnitBuyingEndTime(nowInSeconds - 1000, {from: predictionOperator});
        await poolPrediction.publish({from: predictionOperator});
        await oracle.registerPrediction(poolPrediction.address, {from: oracleOperator});
        await oracle.setOutcome(poolPrediction.address, "300", {from: oracleOperator});

        //await poolPrediction.resolve({from: predictionOperator});
        await poolPrediction.contract.resolve['']({from: predictionOperator});

        await poolPrediction.withdrawPrize({from: player1});

        let player1Tokens = await stoxTestToken.balanceOf(player1);
        let tokenPool = await poolPrediction.tokenPool.call();
        let predictionTokens = await stoxTestToken.balanceOf.call(poolPrediction.address);

        assert.equal(player1Tokens, 1000);
        assert.equal(predictionTokens, 5000);
    });
    
    it("verify that a operator can refund a user for non-resolved prediction", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.relative);
        await poolPrediction.publish({from: predictionOperator});

        await initPlayers(poolPrediction.address);
        await poolPrediction.placeTokens(1000, 100, {from: player1});
        
        await poolPrediction.refundUser(player1, 100, {from: predictionOperator});

        let player1Tokens = await stoxTestToken.balanceOf(player1);
        let tokenPool = await poolPrediction.tokenPool.call();
        let predictionTokens = await stoxTestToken.balanceOf.call(poolPrediction.address);

        assert.equal(player1Tokens, 1000);
        assert.equal(tokenPool, 0);
        assert.equal(predictionTokens, 0);
    });
    
    it("verify that a user can be refunded, place more tokens and get the prize", async function() {
        let poolPrediction = await initPredictionWithOutcomes(calculationType.breakEven);
        await poolPrediction.publish({from: predictionOperator});

        await initPlayers(poolPrediction.address);
        await poolPrediction.placeTokens(1000, 100, {from: player1});
        
        await poolPrediction.refundUser(player1, 100, {from: predictionOperator});
        //let player1Tokens = await stoxTestToken.balanceOf.call(player1);
        
        await stoxTestToken.approve(poolPrediction.address, 0, {from: player1});
        await stoxTestToken.approve(poolPrediction.address, 1000, {from: player1});
        
        await poolPrediction.placeTokens(1000, 200, {from: player1});
        await poolPrediction.pause({from: predictionOperator});
        await poolPrediction.setUnitBuyingEndTime(nowInSeconds - 1000, {from: predictionOperator});
        await poolPrediction.publish({from: predictionOperator});
        
        await oracle.registerPrediction(poolPrediction.address, {from: oracleOperator});
        await oracle.setOutcome(poolPrediction.address, 200, {from: oracleOperator});

        await poolPrediction.contract.resolve['']({from: predictionOperator});
        
        await poolPrediction.withdrawPrize({from: player1});

        let player1Tokens = await stoxTestToken.balanceOf(player1);
        let predictionTokens = await stoxTestToken.balanceOf.call(poolPrediction.address);

        assert.equal(player1Tokens, 1000);
        assert.equal(predictionTokens, 0);
        
    });
    
});