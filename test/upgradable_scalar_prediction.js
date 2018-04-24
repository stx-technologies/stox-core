const utils = require('./helpers/Utils');
const path = require('path');
const fs = require('fs');
const solc = require('solc');
const web3utils = require('web3-utils');

const ExtendedERC20Token = artifacts.require("./token/ExtendedERC20Token.sol");
const ScalarPrediction = artifacts.require("./predictions/types/scalar/ScalarPrediction.sol");
const UpgradablePredictionFactory = artifacts.require("./predictions/factory/UpgradablePredictionFactory.sol");
const IScalarPredictionFactoryImpl = artifacts.require("./predictions/factory/IScalarPredictionFactoryImpl.sol");
const ScalarPredictionFactoryImpl = artifacts.require("./predictions/factory/ScalarPredictionFactoryImpl.sol");
const ScalarOracle = artifacts.require("./oracles/types/ScalarOracle.sol");
const UpgradableOracleFactory = artifacts.require("./oracles/factory/UpgradableOracleFactory.sol");
const IUpgradableOracleFactoryImpl = artifacts.require("./oracles/factory/IUpgradableOracleFactoryImpl.sol");
const OracleFactoryImpl = artifacts.require("./oracles/factory/OracleFactoryImpl.sol");

let stoxTestToken;
let predictionFactory;
let upgradablePredictionFactory;
let iScalarPredictionFactoryImpl;
let scalarPredictionFactoryImpl;
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

contract('ScalarPrediction', function(accounts) {

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
    };

    async function initOracle() {
        await iUpgradableOracleFactoryImpl.createScalarOracle("Test Oracle", {from: oracleOperator}).then(function(result) {
            oracle = ScalarOracle.at(getLogArg(result, "_newOracle"));
        });
    }

    async function initPrediction(calcType) {
        let scalarPrediction;
        await iScalarPredictionFactoryImpl.createScalarPrediction(oracle.address, tommorowInSeconds, tommorowInSeconds, "Test Prediction", stoxTestToken.address, calcType, {from: predictionOperator}).then(function(result) {
            scalarPrediction = ScalarPrediction.at(getLogArg(result, "_newPrediction"));
        });
        
        return scalarPrediction;
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
            'predictions/types/scalar/IScalarPredictionPrizeCalculation.sol': fs.readFileSync('../stox-core/contracts/predictions/types/scalar/IScalarPredictionPrizeCalculation.sol', 'utf8'),
            'predictions/types/scalar/IScalarPredictionPrizeDistribution.sol': fs.readFileSync('../stox-core/contracts/predictions/types/scalar/IScalarPredictionPrizeDistribution.sol', 'utf8'),
            'predictions/types/scalar/Scalarrediction.sol': fs.readFileSync('../stox-core/contracts/predictions/types/scalar/ScalarPrediction.sol', 'utf8'),
            'predictions/types/scalar/ScalarPredictionCalculationMethods.sol': fs.readFileSync('../stox-core/contracts/predictions/types/scalar/ScalarPredictionCalculationMethods.sol', 'utf8'),
            'predictions/types/scalar/ScalarPredictionPrizeCalculation.sol': fs.readFileSync('../stox-core/contracts/predictions/types/scalar/ScalarPredictionPrizeCalculation.sol', 'utf8'),
            'predictions/types/scalar/ScalarPredictionPrizeDistribution.sol': fs.readFileSync('../stox-core/contracts/predictions/types/scalar/ScalarPredictionPrizeDistribution.sol', 'utf8'),
            'predictions/factory/IUpgradablePredictionFactoryImpl.sol': fs.readFileSync('../stox-core/contracts/predictions/factory/IUpgradablePredictionFactoryImpl.sol', 'utf8'),
            'oracles/types/ScalarOracle.sol': fs.readFileSync('../stox-core/contracts/oracles/types/MultipleOutcomeOracle.sol', 'utf8'),
            'token/IERC20Token.sol': fs.readFileSync('../stox-core/contracts/token/IERC20Token.sol', 'utf8'),
            'Ownable.sol': fs.readFileSync('../stox-core/contracts/Ownable.sol', 'utf8'),
            'Utils.sol': fs.readFileSync('../stox-core/contracts/Utils.sol', 'utf8'),
            'predictions/factory/ScalarPredictionFactoryImpl.sol': fs.readFileSync('../stox-core/contracts/predictions/factory/ScalarPredictionFactoryImpl.sol', 'utf8')
            };
        
            // Compile the source code
        let output = await solc.compile({sources: input}, 1);
        console.log({output})
        let abi = await output.contracts['predictions/factory/ScalarPredictionFactoryImpl.sol:ScalarPredictionFactoryImpl'].interface;
        let bytecode = await '0x' + output.contracts['predictions/factory/ScalarPredictionFactoryImpl.sol:ScalarPredictionFactoryImpl'].bytecode;
        
        let deployed = await web3.eth.contract(JSON.parse(abi));
        let contractData = await deployed.new.getData({data: bytecode});
        let gasEstimate = await web3.eth.estimateGas({data: contractData});

        return gasEstimate;
    }

    before(async function() {
        // runs before all tests in this block
        stoxTestToken = await ExtendedERC20Token.new("Stox Text", "STX", 18);
        
        oracleFactoryImpl = await OracleFactoryImpl.new();
        upgradableOracleFactory = await UpgradableOracleFactory.new(oracleFactoryImpl.address, {from: oracleOperator});
        iUpgradableOracleFactoryImpl = IUpgradableOracleFactoryImpl.at(upgradableOracleFactory.address, {from: oracleOperator});
        
        //console.log("gas: " + await checkGas());
                
        scalarPredictionFactoryImpl = await ScalarPredictionFactoryImpl.new();
        upgradablePredictionFactory = await UpgradablePredictionFactory.new(scalarPredictionFactoryImpl.address, {from: predictionOperator});
        iScalarPredictionFactoryImpl = IScalarPredictionFactoryImpl.at(upgradablePredictionFactory.address, {from: predictionOperator});
        
        var tomorrow = new Date();
        tomorrow.setDate((new Date).getDate() + 1);
        tommorowInSeconds = Math.round(tomorrow.getTime() / 1000);
        nowInSeconds = Math.round((new Date()).getTime() / 1000);

        await initOracle();
        
      });
    
    it("should throw if prediction name is invalid", async function() {
        await iScalarPredictionFactoryImpl.createScalarPrediction(oracle.address, tommorowInSeconds, tommorowInSeconds, "Test Prediction", stoxTestToken.address, calculationType.breakEven, {from: predictionOperator}).then(function(result) {
            scalarPrediction = ScalarPrediction.at(getLogArg(result, "_newPrediction"));
        });
                        
        let name = await scalarPrediction.name.call();

        assert.equal(name, "Test Prediction");
    });
   
    it("should throw if oracle address is invalid", async function() {
        try {
            await iScalarPredictionFactoryImpl.createScalarPrediction(0, tommorowInSeconds, tommorowInSeconds, "Test Prediction", stoxTestToken.address, calculationType.breakEven, {from: predictionOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if prediction end time is invalid", async function() {
        try {
            await iScalarPredictionFactoryImpl.createScalarPrediction(oracle.address, 0, tommorowInSeconds, "Test Prediction", stoxTestToken.address, calculationType.breakEven, {from: predictionOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });
     
    it("should throw if units buying end time is invalid", async function() {
        try {
            await iScalarPredictionFactoryImpl.createScalarPrediction(oracle.address, tommorowInSeconds, 0, "Test Prediction", stoxTestToken.address, calculationType.breakEven, {from: predictionOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if prediction end time < units buying end time", async function() {
        try {
            await iScalarPredictionFactoryImpl.createScalarPrediction(oracle.address, tommorowInSeconds, (tommorowInSeconds + 1000), "Test Prediction", stoxTestToken.address, calculationType.breakEven, {from: predictionOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });
        
    it("should throw if a non owner publish the prediction", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);

        try {
            await scalarPrediction.publish({from: player1});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("verify that the owner published the prediction", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        
        await scalarPrediction.publish({from: predictionOperator});
        let predictionStatus = await scalarPrediction.status.call();
        assert.equal(predictionStatus, 1);
    });
    
    it("should throw if an already published prediction is published", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        await scalarPrediction.publish({from: predictionOperator});

        try {
            await scalarPrediction.publish({from: predictionOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if a canceled prediction is published", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        await scalarPrediction.publish({from: predictionOperator});
        await scalarPrediction.cancel({from: predictionOperator});

        try {
            await scalarPrediction.publish({from: predictionOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("verify that a paused prediction can be published", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        await scalarPrediction.publish({from: predictionOperator});
        await scalarPrediction.pause({from: predictionOperator});
        let predictionStatus = await scalarPrediction.status.call();
        assert.equal(predictionStatus, 3);

        await scalarPrediction.publish({from: predictionOperator});
        predictionStatus = await scalarPrediction.status.call();
        assert.equal(predictionStatus, 1);
    });

    it("verify that the units buying end time can be changed when prediction is initializing", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        
        await scalarPrediction.setUnitBuyingEndTime(tommorowInSeconds - 1000, {from: predictionOperator});
        let unitBuyingEndTimeSeconds = await scalarPrediction.unitBuyingEndTimeSeconds.call();
        assert.equal(unitBuyingEndTimeSeconds, tommorowInSeconds - 1000);
    });

    it("verify that the units buying end time can be changed when prediction is paused", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        await scalarPrediction.publish({from: predictionOperator});
        await scalarPrediction.pause({from: predictionOperator});

        await scalarPrediction.setUnitBuyingEndTime(tommorowInSeconds - 1000, {from: predictionOperator});
        let unitBuyingEndTimeSeconds = await scalarPrediction.unitBuyingEndTimeSeconds.call();
        assert.equal(unitBuyingEndTimeSeconds, tommorowInSeconds - 1000);
    });

    it("should throw if units buying end time is changed when prediction is published", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        await scalarPrediction.publish({from: predictionOperator});

        try {
            await scalarPrediction.setUnitBuyingEndTime(tommorowInSeconds - 1000, {from: predictionOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if a non owner changes units buying end time", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        
        try {
            await scalarPrediction.setUnitBuyingEndTime(tommorowInSeconds - 1000, {from: player1});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if trying to place tokens on a non integer outcome", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        await scalarPrediction.publish({from: predictionOperator});
        
        await initPlayers(scalarPrediction.address);

        try {
            await scalarPrediction.placeTokens(1000, "string", {from: player1});
        } catch (error) {
            return error.toString().includes('not a number');
        }

        assert.equal(false, "Didn't throw");
    });

    it("verify that the prediction end time can be changed when prediction is initializing", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        
        await scalarPrediction.setPredictionEndTime(tommorowInSeconds + 1000, {from: predictionOperator});
        let predictionEndTimeSeconds = await scalarPrediction.predictionEndTimeSeconds.call();
        assert.equal(predictionEndTimeSeconds, tommorowInSeconds + 1000);
    });

    it("verify that the prediction end time can be changed when prediction is paused", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        await scalarPrediction.publish({from: predictionOperator});
        await scalarPrediction.pause({from: predictionOperator});

        await scalarPrediction.setPredictionEndTime(tommorowInSeconds + 1000, {from: predictionOperator});
        let predictionEndTimeSeconds = await scalarPrediction.predictionEndTimeSeconds.call();
        assert.equal(predictionEndTimeSeconds, tommorowInSeconds + 1000);
    });

    it("should throw if a non owner changes prediction end time", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        
        try {
            await scalarPrediction.setPredictionEndTime(tommorowInSeconds + 1000, {from: player1});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("verify that the prediction name can be changed", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        
        await scalarPrediction.setPredictionName("new name", {from: predictionOperator});
        let predictionName = await scalarPrediction.name.call();
        assert.equal(predictionName, "new name");
    });

    it("should throw if a non owner changes prediction name", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        
        try {
            await scalarPrediction.setPredictionName("new name", {from: player1});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("verify that the oracle can be changed", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        let newOracle;

        await iUpgradableOracleFactoryImpl.createScalarOracle("Test Oracle", {from: oracleOperator}).then(function(result) {
            newOracle = ScalarOracle.at(getLogArg(result, "_newOracle"));
        });    

        //await oracleFactory.createOracle("Test Oracle", {from: oracleOperator}).then(function(result) {
        //    newOracle = Oracle.at(getLogArg(result, "_oracle"));
        //});

        await scalarPrediction.setOracle(newOracle.address, {from: predictionOperator});
        let oracleAddress = await scalarPrediction.oracleAddress.call();
        assert.equal(oracleAddress, newOracle.address);
    });
    
    it("verify that a user can buy a unit", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        await scalarPrediction.publish({from: predictionOperator});
        await initPlayers(scalarPrediction.address);
        
        await scalarPrediction.placeTokens(1000, 100, {from: player1});
        //let unit = await scalarPrediction.units.call(0);
        //verifyUnit(unit, 1, 1, 1000, false, player1);

        let tokenPool = await scalarPrediction.tokenPool.call();
        let predictionTokens = await stoxTestToken.balanceOf.call(scalarPrediction.address);

        assert.equal(tokenPool, 1000);
        assert.equal(predictionTokens.toNumber(), 1000);
    });
    
    it("verify that multiple users can buy units", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        await scalarPrediction.publish({from: predictionOperator});
        await initPlayers(scalarPrediction.address);

        await scalarPrediction.placeTokens(1000, 100, {from: player1});
        await scalarPrediction.placeTokens(2000, 200, {from: player2});
        await scalarPrediction.placeTokens(3000, 100, {from: player3});

        let tokenPool = await scalarPrediction.tokenPool.call();
        let predictionTokens = await stoxTestToken.balanceOf.call(scalarPrediction.address);

        assert.equal(tokenPool, 6000);
        assert.equal(predictionTokens, 6000);
    });
    
    it("should throw if trying to resolve a prediction before oracle has been set", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        await scalarPrediction.publish({from: predictionOperator});
        await initPlayers(scalarPrediction.address);

        await scalarPrediction.placeTokens(1000, 100, {from: player1});
        await scalarPrediction.placeTokens(2000, 200, {from: player2});
        await scalarPrediction.placeTokens(3000, 100, {from: player3});

        await scalarPrediction.pause({from: predictionOperator});
        await scalarPrediction.setUnitBuyingEndTime(nowInSeconds - 1000, {from: predictionOperator});
        await scalarPrediction.publish({from: predictionOperator});
        
        try {
            //await scalarPrediction.resolve({from: predictionOperator});
            await scalarPrediction.contract.resolve['']({from: predictionOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });
    
    it("should throw if trying to resolve an prediction before units buying time has ended", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        await scalarPrediction.publish({from: predictionOperator});
        await initPlayers(scalarPrediction.address);

        await scalarPrediction.placeTokens(1000, 100, {from: player1});
        await scalarPrediction.placeTokens(2000, 200, {from: player2});
        await scalarPrediction.placeTokens(3000, 100, {from: player3});

        await oracle.registerPrediction(scalarPrediction.address, {from: oracleOperator});
        await oracle.setOutcome(scalarPrediction.address, 100, {from: oracleOperator});

        try {
            //await scalarPrediction.resolve({from: predictionOperator});
            await scalarPrediction.contract.resolve['']({from: predictionOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });
    
    it("verify that a prediction can be resolved", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        await scalarPrediction.publish({from: predictionOperator});
        await initPlayers(scalarPrediction.address);

        await scalarPrediction.placeTokens(1000, 100, {from: player1});
        await scalarPrediction.placeTokens(2000, 200, {from: player2});
        await scalarPrediction.placeTokens(3000, 100, {from: player3});

        await scalarPrediction.pause({from: predictionOperator});
        await scalarPrediction.setUnitBuyingEndTime(nowInSeconds - 1000, {from: predictionOperator});
        await scalarPrediction.publish({from: predictionOperator});
        await oracle.registerPrediction(scalarPrediction.address, {from: oracleOperator});
        await oracle.setOutcome(scalarPrediction.address, 100, {from: oracleOperator});
        
         
        //await scalarPrediction.resolve({from: predictionOperator});
        await scalarPrediction.contract.resolve['']({from: predictionOperator});
        
        predictionStatus = await scalarPrediction.status.call();
        assert.equal(predictionStatus, 2);

        let winningOutcome = await scalarPrediction.winningOutcome.call();
        assert.equal(isEventArgValid(winningOutcome, 100),true);

        let player1Winnings = await scalarPrediction.calculateUserWithdrawAmount(player1);
        let player2Winnings = await scalarPrediction.calculateUserWithdrawAmount(player2);
        let player3Winnings = await scalarPrediction.calculateUserWithdrawAmount(player3);

        assert.equal(player1Winnings, 1000);
        assert.equal(player2Winnings, 2000);
        assert.equal(player3Winnings, 3000);
    });
    
    it("verify that a user can withdraw funds from a unit", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        await scalarPrediction.publish({from: predictionOperator});
        
        await initPlayers(scalarPrediction.address);
        await scalarPrediction.placeTokens(1000, 100, {from: player1});
        await scalarPrediction.placeTokens(2000, 200, {from: player2});
        await scalarPrediction.placeTokens(3000, "300", {from: player3});

        await scalarPrediction.pause({from: predictionOperator});
        await scalarPrediction.setUnitBuyingEndTime(nowInSeconds - 1000, {from: predictionOperator});
        await scalarPrediction.publish({from: predictionOperator});
        await oracle.registerPrediction(scalarPrediction.address, {from: oracleOperator});
        await oracle.setOutcome(scalarPrediction.address, 100, {from: oracleOperator});

        //await scalarPrediction.resolve({from: predictionOperator});
        await scalarPrediction.contract.resolve['']({from: predictionOperator});

        await scalarPrediction.withdrawPrize({from: player1});

        let player1Tokens = await stoxTestToken.balanceOf(player1);
        let tokenPool = await scalarPrediction.tokenPool.call();
        let predictionTokens = await stoxTestToken.balanceOf.call(scalarPrediction.address);

        assert.equal(player1Tokens, 1000);
        assert.equal(predictionTokens, 5000);
    });

    it("verify that a user can withdraw funds from a unit, break even method", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        await scalarPrediction.publish({from: predictionOperator});
        
        await initPlayers(scalarPrediction.address);
        await scalarPrediction.placeTokens(1000, 100, {from: player1});
        await scalarPrediction.placeTokens(2000, 200, {from: player2});
        await scalarPrediction.placeTokens(3000, 100, {from: player3});

        await scalarPrediction.pause({from: predictionOperator});
        await scalarPrediction.setUnitBuyingEndTime(nowInSeconds - 1000, {from: predictionOperator});
        await scalarPrediction.publish({from: predictionOperator});
        await oracle.registerPrediction(scalarPrediction.address, {from: oracleOperator});
        await oracle.setOutcome(scalarPrediction.address, 100, {from: oracleOperator});

        //await scalarPrediction.resolve({from: predictionOperator});
        await scalarPrediction.contract.resolve['']({from: predictionOperator});

        await scalarPrediction.withdrawPrize({from: player1});

        let player1Tokens = await stoxTestToken.balanceOf(player1);
        let tokenPool = await scalarPrediction.tokenPool.call();
        let predictionTokens = await stoxTestToken.balanceOf.call(scalarPrediction.address);

        assert.equal(player1Tokens, 1000);
        assert.equal(predictionTokens, 5000);
    });

    it("verify that a user can withdraw funds from multiple units", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        await scalarPrediction.publish({from: predictionOperator});
        
        await initPlayers(scalarPrediction.address);
        await scalarPrediction.placeTokens(1000, 100, {from: player1});
        await scalarPrediction.placeTokens(2000, 200, {from: player2});
        await scalarPrediction.placeTokens(2000, 100, {from: player3});
        await scalarPrediction.placeTokens(1000, 100, {from: player3});

        await scalarPrediction.pause({from: predictionOperator});
        await scalarPrediction.setUnitBuyingEndTime(nowInSeconds - 1000, {from: predictionOperator});
        await scalarPrediction.publish({from: predictionOperator});
        await oracle.registerPrediction(scalarPrediction.address, {from: oracleOperator});
        await oracle.setOutcome(scalarPrediction.address, 100, {from: oracleOperator});

        //await scalarPrediction.resolve({from: predictionOperator});
        await scalarPrediction.contract.resolve['']({from: predictionOperator});

        await scalarPrediction.withdrawPrize({from: player3});

        let player3Tokens = await stoxTestToken.balanceOf(player3);
        let tokenPool = await scalarPrediction.tokenPool.call();
        let predictionTokens = await stoxTestToken.balanceOf.call(scalarPrediction.address);

        assert.equal(player3Tokens, 3000);
        assert.equal(predictionTokens, 3000);
    });
    
    it("verify that the prediction can be canceled", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        await scalarPrediction.publish({from: predictionOperator});
        await scalarPrediction.cancel({from: predictionOperator});
        
        predictionStatus = await scalarPrediction.status.call();
        assert.equal(predictionStatus, 4);
    });

    it("verify that a operator can refund a user after the prediction is canceled", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        await scalarPrediction.publish({from: predictionOperator});

        await initPlayers(scalarPrediction.address);
        await scalarPrediction.placeTokens(1000, 100, {from: player1});
        await scalarPrediction.placeTokens(2000, 200, {from: player2});
        await scalarPrediction.placeTokens(3000, 100, {from: player3});

        await scalarPrediction.cancel({from: predictionOperator});
        await scalarPrediction.refundUser(player1, 100, {from: predictionOperator});

        let player1Tokens = await stoxTestToken.balanceOf(player1);
        let tokenPool = await scalarPrediction.tokenPool.call();
        let predictionTokens = await stoxTestToken.balanceOf.call(scalarPrediction.address);

        assert.equal(player1Tokens, 1000);
        assert.equal(tokenPool, 5000);
        assert.equal(predictionTokens, 5000);
    });

    it("verify that a user can get a refund after the prediction is canceled", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        await scalarPrediction.publish({from: predictionOperator});

        await initPlayers(scalarPrediction.address);
        await scalarPrediction.placeTokens(1000, 100, {from: player1});
        await scalarPrediction.placeTokens(2000, 200, {from: player2});
        await scalarPrediction.placeTokens(3000, 100, {from: player3});

        await scalarPrediction.cancel({from: predictionOperator});
        await scalarPrediction.getRefund(100, {from: player1});

        let player1Tokens = await stoxTestToken.balanceOf(player1);
        let tokenPool = await scalarPrediction.tokenPool.call();
        let predictionTokens = await stoxTestToken.balanceOf.call(scalarPrediction.address);

        assert.equal(player1Tokens, 1000);
        assert.equal(tokenPool, 5000);
        assert.equal(predictionTokens, 5000);
    });
    
    it("verify that an prediction can be paused", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        await scalarPrediction.publish({from: predictionOperator});
        await scalarPrediction.pause({from: predictionOperator});
        
        predictionStatus = await scalarPrediction.status.call();
        assert.equal(predictionStatus, 3);
    });
    

    it ("verify withdraw prize event fired", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        await scalarPrediction.publish({from: predictionOperator});
        
        await initPlayers(scalarPrediction.address);
        await scalarPrediction.placeTokens(1000, 100, {from: player1});
        await scalarPrediction.placeTokens(2000, 200, {from: player2});
        await scalarPrediction.placeTokens(3000, 100, {from: player3});

        await scalarPrediction.pause({from: predictionOperator});
        await scalarPrediction.setUnitBuyingEndTime(nowInSeconds - 1000, {from: predictionOperator});
        await scalarPrediction.publish({from: predictionOperator});
        await oracle.registerPrediction(scalarPrediction.address, {from: oracleOperator});
        await oracle.setOutcome(scalarPrediction.address, 100, {from: oracleOperator});

        //await scalarPrediction.resolve({from: predictionOperator});
        await scalarPrediction.contract.resolve['']({from: predictionOperator});

        tx_result = await scalarPrediction.withdrawPrize({from: player1});

        let event  = getLog(tx_result,"event")
        assert.equal(event,"PrizeDistributed")
    });

    it ("verify place tokens event fired", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        await scalarPrediction.publish({from: predictionOperator});
        
        await initPlayers(scalarPrediction.address);
        tx_result = await scalarPrediction.placeTokens(1000, 100, {from: player1});

        let event  = getLog(tx_result,"event")
        assert.equal(event,"TokensPlacedOnOutcome")

    });

    it("verify that a user can get a refund after the prediction is canceled", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        await scalarPrediction.publish({from: predictionOperator});

        await initPlayers(scalarPrediction.address);
        await scalarPrediction.placeTokens(1000, 100, {from: player1});
        await scalarPrediction.placeTokens(2000, 200, {from: player2});
        await scalarPrediction.placeTokens(3000, 100, {from: player3});

        await scalarPrediction.cancel({from: predictionOperator});
        tx_result = await scalarPrediction.getRefund(100, {from: player1});

        let event  = getLog(tx_result,"event")
        assert.equal(event,"UserRefunded")
    });

    it ("verify withdraw prize amount event argument correct", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        await scalarPrediction.publish({from: predictionOperator});
        
        await initPlayers(scalarPrediction.address);
        await scalarPrediction.placeTokens(1000, 100, {from: player1});
        await scalarPrediction.placeTokens(2000, 200, {from: player2});
        await scalarPrediction.placeTokens(3000, 100, {from: player3});

        await scalarPrediction.pause({from: predictionOperator});
        await scalarPrediction.setUnitBuyingEndTime(nowInSeconds - 1000, {from: predictionOperator});
        await scalarPrediction.publish({from: predictionOperator});
        await oracle.registerPrediction(scalarPrediction.address, {from: oracleOperator});
        await oracle.setOutcome(scalarPrediction.address, 100, {from: oracleOperator});
        
        await scalarPrediction.contract.resolve['']({from: predictionOperator});
        //await scalarPrediction.resolve({from: predictionOperator});
        
        tx_result = await scalarPrediction.withdrawPrize({from: player1});

        let event  = getLog(tx_result,"event")
        assert.equal(event,"PrizeDistributed")

        assert.equal(isEventArgValid(getLogArg(tx_result,"_tokenAmount"),1000), true);
        
    });
    
    it ("verify place tokens amount and outcome event arguments correct", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        await scalarPrediction.publish({from: predictionOperator});
        
        await initPlayers(scalarPrediction.address);
        tx_result = await scalarPrediction.placeTokens(1000, 100, {from: player1});

        let event  = getLog(tx_result,"event")
        assert.equal(event,"TokensPlacedOnOutcome")

        assert.equal(isEventArgValid(getLogArg(tx_result,"_tokenAmount"),1000), true);
        //assert.equal(isEventArgValid(getLogArg(tx_result,"_outcome"),100), true);
        assert.equal(isEventArgValid(getLogArg(tx_result,"_outcome"),100), true);
        
    });

    it ("verify place tokens amount and negative outcome event arguments correct", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        await scalarPrediction.publish({from: predictionOperator});
        
        await initPlayers(scalarPrediction.address);
        tx_result = await scalarPrediction.placeTokens(1000, -100, {from: player1});

        let event  = getLog(tx_result,"event")
        assert.equal(event,"TokensPlacedOnOutcome")

        assert.equal(isEventArgValid(getLogArg(tx_result,"_tokenAmount"),1000), true);
        //assert.equal(isEventArgValid(getLogArg(tx_result,"_outcome"),100), true);
        assert.equal(isEventArgValid(getLogArg(tx_result,"_outcome"),-100), true);
        
    });

    it("verify refund event arguments correct", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        await scalarPrediction.publish({from: predictionOperator});

        await initPlayers(scalarPrediction.address);
        await scalarPrediction.placeTokens(1000, 100, {from: player1});
        await scalarPrediction.placeTokens(2000, 200, {from: player2});
        await scalarPrediction.placeTokens(3000, 100, {from: player3});

        await scalarPrediction.cancel({from: predictionOperator});
        tx_result = await scalarPrediction.getRefund(100, {from: player1});

        let event  = getLog(tx_result,"event")
        assert.equal(event,"UserRefunded")

        assert.equal(isEventArgValid(getLogArg(tx_result,"_tokenAmount"),1000), true);
        assert.equal(isEventArgValid(getLogArg(tx_result,"_outcome"),100), true);
    });

    it("verify that a user cannot withdraw funds from an un resolved prediction", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        await scalarPrediction.publish({from: predictionOperator});
        
        await initPlayers(scalarPrediction.address);
        await scalarPrediction.placeTokens(1000, 100, {from: player1});
        await scalarPrediction.placeTokens(2000, 200, {from: player2});
        
        await scalarPrediction.pause({from: predictionOperator});
        await scalarPrediction.setUnitBuyingEndTime(nowInSeconds - 1000, {from: predictionOperator});
        await scalarPrediction.publish({from: predictionOperator});
        await oracle.registerPrediction(scalarPrediction.address, {from: oracleOperator});
        await oracle.setOutcome(scalarPrediction.address, 100, {from: oracleOperator});

        try {
             await scalarPrediction.withdrawPrize({from: player1});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
      
    });

    it("should throw if the operator tries to refund a user with 0 tokens on the outcome", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        await scalarPrediction.publish({from: predictionOperator});

        await initPlayers(scalarPrediction.address);
        await scalarPrediction.placeTokens(1000, 100, {from: player1});
        await scalarPrediction.cancel({from: predictionOperator});
        
        try {
            await scalarPrediction.refundUser(player1, 200, {from: predictionOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });
    
    it("should throw if the user tries to get a refund with 0 tokens on the outcome", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        await scalarPrediction.publish({from: predictionOperator});

        await initPlayers(scalarPrediction.address);
        await scalarPrediction.placeTokens(1000, 100, {from: player1});
        await scalarPrediction.cancel({from: predictionOperator});
        
        try {
            await scalarPrediction.getRefund(200, {from: player1});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if the user tries to get a refund twice on the same outcome", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        await scalarPrediction.publish({from: predictionOperator});

        await initPlayers(scalarPrediction.address);
        await scalarPrediction.placeTokens(1000, 100, {from: player1});
        await scalarPrediction.cancel({from: predictionOperator});
        await scalarPrediction.getRefund(100, {from: player1});

        try {
            await scalarPrediction.getRefund(100, {from: player1});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if a user tried to withdraw funds twice", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        await scalarPrediction.publish({from: predictionOperator});
        
        await initPlayers(scalarPrediction.address);
        await scalarPrediction.placeTokens(1000, 100, {from: player1});
        await scalarPrediction.placeTokens(2000, 200, {from: player2});
        await scalarPrediction.placeTokens(3000, 100, {from: player3});

        await scalarPrediction.pause({from: predictionOperator});
        await scalarPrediction.setUnitBuyingEndTime(nowInSeconds - 1000, {from: predictionOperator});
        await scalarPrediction.publish({from: predictionOperator});
        await oracle.registerPrediction(scalarPrediction.address, {from: oracleOperator});
        await oracle.setOutcome(scalarPrediction.address, 100, {from: oracleOperator});

        //await scalarPrediction.resolve({from: predictionOperator});
        await scalarPrediction.contract.resolve['']({from: predictionOperator});

        await scalarPrediction.withdrawPrize({from: player1});

        try {
            await scalarPrediction.withdrawPrize({from: player1});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });
       
    it("should throw if a user tries to place 0 tokens on an outcome", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        await scalarPrediction.publish({from: predictionOperator});
        
        await initPlayers(scalarPrediction.address);
        
        try {
            await scalarPrediction.placeTokens(0, 100, {from: player1});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if an Oracle tries to set an outcome on an unregistered prediction", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        await scalarPrediction.publish({from: predictionOperator});
        
        await initPlayers(scalarPrediction.address);
        
        try {
            await oracle.setOutcome(scalarPrediction.address, 100, {from: oracleOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });
    
    it("should throw if an Oracle tries to set an outcome on a registerd->unregistered prediction", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        await scalarPrediction.publish({from: predictionOperator});
        
        await initPlayers(scalarPrediction.address);
        await oracle.registerPrediction(scalarPrediction.address, {from: oracleOperator});
        await oracle.unRegisterPrediction(scalarPrediction.address, {from: oracleOperator});
        
        try {
            await oracle.setOutcome(scalarPrediction.address, 100, {from: oracleOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });
    
    it("verify that a user can withdraw funds, non-winning outcome", async function() {
        let scalarPrediction = await initPrediction(calculationType.breakEven);
        await scalarPrediction.publish({from: predictionOperator});
        
        await initPlayers(scalarPrediction.address);
        await scalarPrediction.placeTokens(1000, 100, {from: player1});
        await scalarPrediction.placeTokens(2000, 200, {from: player2});
        
        await scalarPrediction.pause({from: predictionOperator});
        await scalarPrediction.setUnitBuyingEndTime(nowInSeconds - 1000, {from: predictionOperator});
        await scalarPrediction.publish({from: predictionOperator});
        await oracle.registerPrediction(scalarPrediction.address, {from: oracleOperator});
        await oracle.setOutcome(scalarPrediction.address, 300, {from: oracleOperator});
        await scalarPrediction.contract.resolve['']({from: predictionOperator});
        
        await scalarPrediction.withdrawPrize({from: player1});
        
        let player1Tokens = await stoxTestToken.balanceOf(player1);
        let tokenPool = await scalarPrediction.tokenPool.call();
        let predictionTokens = await stoxTestToken.balanceOf.call(scalarPrediction.address);

        assert.equal(player1Tokens, 1000);
        assert.equal(predictionTokens, 2000);
    });

        
});