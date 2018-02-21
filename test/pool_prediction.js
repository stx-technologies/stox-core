const utils = require('./helpers/Utils');

const StoxTestToken = artifacts.require("./token/StoxTestToken.sol");
artifacts.require("./predictions/PoolPrediction.sol");
const PoolPrediction = artifacts.require("./predictions/PoolPrediction.sol");
const PredictionFactory = artifacts.require("./predictions/PredictionFactory.sol");
const PredictionFactoryImpl = artifacts.require("./predictions/PredictionFactoryImpl.sol");
const Oracle = artifacts.require("./oracles/Oracle.sol");
const OracleFactory = artifacts.require("./oracles/OracleFactory.sol");
const OracleFactoryImpl = artifacts.require("./oracles/OracleFactoryImpl.sol");

let stoxTestToken;
let predictionFactory;
let predictionFactoryImpl;
let oracleFactory;
let oracleFactoryImpl;
let oracle;

// Accounts
let predictionOperator;
let oracleOperator;
let player1;
let player2;
let player3;

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

    async function initOracle() {
        //oracle = await oracleFactory.createOracle("Test Oracle", {from: oracleOperator});
        await oracleFactory.createOracle("Test Oracle", {from: oracleOperator}).then(function(result) {
            oracle = Oracle.at(getLogArg(result, "_oracle"));
        });
    }

    async function initPrediction() {
        let poolPrediction;
        await predictionFactory.createPoolPrediction(oracle.address, tommorowInSeconds, tommorowInSeconds, "Test Prediction", {from: predictionOperator}).then(function(result) {
            poolPrediction = PoolPrediction.at(getLogArg(result, "_newPrediction"));
        });

        return poolPrediction;
    }

    async function initPredictionWithOutcomes(prediction) {
        let poolPrediction = await initPrediction();

        await poolPrediction.addOutcome("o1", {from: predictionOperator});
        await poolPrediction.addOutcome("o2", {from: predictionOperator});
        await poolPrediction.addOutcome("o3", {from: predictionOperator});

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

    before(async function() {
        // runs before all tests in this block
        stoxTestToken = await StoxTestToken.new("Stox Text", "STX", 18);
        
        oracleFactoryImpl = await OracleFactoryImpl.new()
        oracleFactory = await OracleFactory.new(oracleFactoryImpl.address, {from: factoryOperator});
        
        predictionFactoryImpl = await PredictionFactoryImpl.new(stoxTestToken.address);
        predictionFactory = await PredictionFactory.new(predictionFactoryImpl.address, {from: factoryOperator})

        var tomorrow = new Date();
        tomorrow.setDate((new Date).getDate() + 1);
        tommorowInSeconds = Math.round(tomorrow.getTime() / 1000);
        nowInSeconds = Math.round((new Date()).getTime() / 1000);

        await initOracle();
      });

    it("should throw if prediction name is invalid", async function() {
        await predictionFactory.createPoolPrediction(oracle.address, tommorowInSeconds, tommorowInSeconds, "Test Prediction", {from: predictionOperator}).then(function(result) {
               poolPrediction = PoolPrediction.at(getLogArg(result, "_newPrediction"));
        });
                     
        let name = await poolPrediction.name.call();

        assert.equal(name, "Test Prediction");
     });

    it("should throw if oracle address is invalid", async function() {
        try {
            await predictionFactory.createPoolPrediction(0, tommorowInSeconds, tommorowInSeconds, "Test Prediction", {from: predictionOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if prediction end time is invalid", async function() {
        try {
            await predictionFactory.createPoolPrediction(oracle.address, 0, tommorowInSeconds, "Test Prediction", {from: predictionOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if units buying end time is invalid", async function() {
        try {
            await predictionFactory.createPoolPrediction(oracle.address, tommorowInSeconds, 0, "Test Prediction", {from: predictionOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if units buying end time is invalid", async function() {
        try {
            await predictionFactory.createPoolPrediction(oracle.address, tommorowInSeconds, 0, "Test Prediction", {from: predictionOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if prediction end time < units buying end time", async function() {
        try {
            await predictionFactory.createPoolPrediction(oracle.address, tommorowInSeconds, (tommorowInSeconds + 1000), "Test Prediction", {from: predictionOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if outcome name is invalid", async function() {
        let poolPrediction = await initPrediction();
        
        try {
            await poolPrediction.addOutcome("", {from: predictionOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if a non owner added outcome", async function() {
        let poolPrediction = await initPrediction();

        try {
            await poolPrediction.addOutcome("outcome1", {from: player1});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("verify that the owner can add an outcome", async function() {
        let poolPrediction = await initPrediction();
        await poolPrediction.addOutcome("outcome1", {from: predictionOperator});
        let outcomeName = await poolPrediction.getOutcome(1);
        
        assert.equal(outcomeName, "outcome1");
    });

    it("should throw if prediction is published without outcomes", async function() {
        let poolPrediction = await initPrediction();

        try {
            await poolPrediction.publish({from: predictionOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if prediction is published with 1 outcome", async function() {
        let poolPrediction = await initPrediction();

        await poolPrediction.addOutcome("outcome1", {from: predictionOperator});
        try {
            await poolPrediction.publish({from: predictionOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if a non owner publish the prediction", async function() {
        let poolPrediction = await initPredictionWithOutcomes();

        try {
            await poolPrediction.publish({from: player1});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("verify that the owner published the prediction", async function() {
        let poolPrediction = await initPredictionWithOutcomes();

        await poolPrediction.publish({from: predictionOperator});
        let predictionStatus = await poolPrediction.status.call();
        assert.equal(predictionStatus, 1);
    });

    it("should throw if an already published prediction is published", async function() {
        let poolPrediction = await initPredictionWithOutcomes();
        await poolPrediction.publish({from: predictionOperator});

        try {
            await poolPrediction.publish({from: predictionOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if a canceled prediction is published", async function() {
        let poolPrediction = await initPredictionWithOutcomes();
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
        let poolPrediction = await initPredictionWithOutcomes();
        await poolPrediction.publish({from: predictionOperator});
        await poolPrediction.pause({from: predictionOperator});
        let predictionStatus = await poolPrediction.status.call();
        assert.equal(predictionStatus, 3);

        await poolPrediction.publish({from: predictionOperator});
        predictionStatus = await poolPrediction.status.call();
        assert.equal(predictionStatus, 1);
    });

    it("verify that the units buying end time can be changed when prediction is initializing", async function() {
        let poolPrediction = await initPrediction();

        await poolPrediction.setUnitBuyingEndTime(tommorowInSeconds - 1000, {from: predictionOperator});
        let unitBuyingEndTimeSeconds = await poolPrediction.unitBuyingEndTimeSeconds.call();
        assert.equal(unitBuyingEndTimeSeconds, tommorowInSeconds - 1000);
    });

    it("verify that the units buying end time can be changed when prediction is paused", async function() {
        let poolPrediction = await initPredictionWithOutcomes();
        await poolPrediction.publish({from: predictionOperator});
        await poolPrediction.pause({from: predictionOperator});

        await poolPrediction.setUnitBuyingEndTime(tommorowInSeconds - 1000, {from: predictionOperator});
        let unitBuyingEndTimeSeconds = await poolPrediction.unitBuyingEndTimeSeconds.call();
        assert.equal(unitBuyingEndTimeSeconds, tommorowInSeconds - 1000);
    });

    it("should throw if units buying end time is changed when prediction is published", async function() {
        let poolPrediction = await initPredictionWithOutcomes();
        await poolPrediction.publish({from: predictionOperator});

        try {
            await poolPrediction.setUnitBuyingEndTime(tommorowInSeconds - 1000, {from: predictionOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if a non owner changes units buying end time", async function() {
        let poolPrediction = await initPrediction();

        try {
            await poolPrediction.setUnitBuyingEndTime(tommorowInSeconds - 1000, {from: player1});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("verify that the prediction end time can be changed when prediction is initializing", async function() {
        let poolPrediction = await initPrediction();

        await poolPrediction.setPredictionEndTime(tommorowInSeconds + 1000, {from: predictionOperator});
        let predictionEndTimeSeconds = await poolPrediction.predictionEndTimeSeconds.call();
        assert.equal(predictionEndTimeSeconds, tommorowInSeconds + 1000);
    });

    it("verify that the prediction end time can be changed when prediction is paused", async function() {
        let poolPrediction = await initPredictionWithOutcomes();
        await poolPrediction.publish({from: predictionOperator});
        await poolPrediction.pause({from: predictionOperator});

        await poolPrediction.setPredictionEndTime(tommorowInSeconds + 1000, {from: predictionOperator});
        let predictionEndTimeSeconds = await poolPrediction.predictionEndTimeSeconds.call();
        assert.equal(predictionEndTimeSeconds, tommorowInSeconds + 1000);
    });

    it("should throw if a non owner changes prediction end time", async function() {
        let poolPrediction = await initPrediction();

        try {
            await poolPrediction.setPredictionEndTime(tommorowInSeconds + 1000, {from: player1});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("verify that the prediction name can be changed", async function() {
        let poolPrediction = await initPrediction();

        await poolPrediction.setPredictionName("new name", {from: predictionOperator});
        let predictionName = await poolPrediction.name.call();
        assert.equal(predictionName, "new name");
    });

    it("should throw if a non owner changes prediction name", async function() {
        let poolPrediction = await initPrediction();

        try {
            await poolPrediction.setPredictionName("new name", {from: player1});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("verify that the oracle can be changed", async function() {
        let poolPrediction = await initPrediction();
        let newOracle;

        await oracleFactory.createOracle("Test Oracle", {from: oracleOperator}).then(function(result) {
            newOracle = Oracle.at(getLogArg(result, "_oracle"));
        });

        await poolPrediction.setOracle(newOracle.address, {from: predictionOperator});
        let oracleAddress = await poolPrediction.oracleAddress.call();
        assert.equal(oracleAddress, newOracle.address);
    });

    it("verify that a user can buy a unit", async function() {
        let poolPrediction = await initPredictionWithOutcomes();
        await poolPrediction.publish({from: predictionOperator});
        await initPlayers(poolPrediction.address);

        await poolPrediction.buyUnit(1000, 1, {from: player1});
        let unit = await poolPrediction.units.call(0);
        verifyUnit(unit, 1, 1, 1000, false, player1);

        let tokenPool = await poolPrediction.tokenPool.call();
        let predictionTokens = await stoxTestToken.balanceOf.call(poolPrediction.address);

        assert.equal(tokenPool, 1000);
        assert.equal(predictionTokens, 1000);
    });

    it("verify that multiple users can buy units", async function() {
        let poolPrediction = await initPredictionWithOutcomes();
        await poolPrediction.publish({from: predictionOperator});
        await initPlayers(poolPrediction.address);

        await poolPrediction.buyUnit(1000, 1, {from: player1});
        await poolPrediction.buyUnit(2000, 2, {from: player2});
        await poolPrediction.buyUnit(3000, 1, {from: player3});

        let unit;
        unit = await poolPrediction.units.call(0);
        verifyUnit(unit, 1, 1, 1000, false, player1);
        unit = await poolPrediction.units.call(1);
        verifyUnit(unit, 2, 2, 2000, false, player2);
        unit = await poolPrediction.units.call(2);
        verifyUnit(unit, 3, 1, 3000, false, player3);

        let tokenPool = await poolPrediction.tokenPool.call();
        let predictionTokens = await stoxTestToken.balanceOf.call(poolPrediction.address);

        assert.equal(tokenPool, 6000);
        assert.equal(predictionTokens, 6000);
    });

    it("should throw if trying to resolve an prediction before oracle has been set", async function() {
        let poolPrediction = await initPredictionWithOutcomes();
        await poolPrediction.publish({from: predictionOperator});
        await initPlayers(poolPrediction.address);
        await poolPrediction.buyUnit(1000, 1, {from: player1});
        await poolPrediction.buyUnit(2000, 2, {from: player2});
        await poolPrediction.buyUnit(3000, 1, {from: player3});

        await poolPrediction.pause({from: predictionOperator});
        await poolPrediction.setUnitBuyingEndTime(nowInSeconds - 1000, {from: predictionOperator});
        await poolPrediction.publish({from: predictionOperator});

        try {
            await poolPrediction.resolve({from: predictionOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if trying to resolve an prediction before units buying time has ended", async function() {
        let poolPrediction = await initPredictionWithOutcomes();
        await poolPrediction.publish({from: predictionOperator});
        await initPlayers(poolPrediction.address);
        await poolPrediction.buyUnit(1000, 1, {from: player1});
        await poolPrediction.buyUnit(2000, 2, {from: player2});
        await poolPrediction.buyUnit(3000, 1, {from: player3});

        await oracle.registerPrediction(poolPrediction.address, {from: oracleOperator});
        await oracle.setOutcome(poolPrediction.address, 1, {from: oracleOperator});

        try {
            await poolPrediction.resolve({from: predictionOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("verify that an prediction can be resolved", async function() {
        let poolPrediction = await initPredictionWithOutcomes();
        await poolPrediction.publish({from: predictionOperator});
        
        await initPlayers(poolPrediction.address);
        await poolPrediction.buyUnit(1000, 1, {from: player1});
        await poolPrediction.buyUnit(2000, 2, {from: player2});
        await poolPrediction.buyUnit(3000, 1, {from: player3});

        await poolPrediction.pause({from: predictionOperator});
        await poolPrediction.setUnitBuyingEndTime(nowInSeconds - 1000, {from: predictionOperator});
        await poolPrediction.publish({from: predictionOperator});
        await oracle.registerPrediction(poolPrediction.address, {from: oracleOperator});
        await oracle.setOutcome(poolPrediction.address, 1, {from: oracleOperator});

        await poolPrediction.resolve({from: predictionOperator});

        predictionStatus = await poolPrediction.status.call();
        assert.equal(predictionStatus, 2);

        let winnigOutcome = await poolPrediction.winningOutcomeId.call();
        assert.equal(winnigOutcome, 1);

        let player1Winnings = await poolPrediction.calculateUserUnitsWithdrawValue(player1);
        let player2Winnings = await poolPrediction.calculateUserUnitsWithdrawValue(player2);
        let player3Winnings = await poolPrediction.calculateUserUnitsWithdrawValue(player3);

        assert.equal(player1Winnings, 1500);
        assert.equal(player2Winnings, 0);
        assert.equal(player3Winnings, 4500);
    });

    it("verify that a user can withdraw funds from a unit", async function() {
        let poolPrediction = await initPredictionWithOutcomes();
        await poolPrediction.publish({from: predictionOperator});
        
        await initPlayers(poolPrediction.address);
        await poolPrediction.buyUnit(1000, 1, {from: player1});
        await poolPrediction.buyUnit(2000, 2, {from: player2});
        await poolPrediction.buyUnit(3000, 1, {from: player3});

        await poolPrediction.pause({from: predictionOperator});
        await poolPrediction.setUnitBuyingEndTime(nowInSeconds - 1000, {from: predictionOperator});
        await poolPrediction.publish({from: predictionOperator});
        await oracle.registerPrediction(poolPrediction.address, {from: oracleOperator});
        await oracle.setOutcome(poolPrediction.address, 1, {from: oracleOperator});

        await poolPrediction.resolve({from: predictionOperator});

        await poolPrediction.withdrawUnits({from: player1});

        let player1Tokens = await stoxTestToken.balanceOf(player1);
        let tokenPool = await poolPrediction.tokenPool.call();
        let predictionTokens = await stoxTestToken.balanceOf.call(poolPrediction.address);

        assert.equal(player1Tokens, 1500);
        assert.equal(predictionTokens, 4500);
    });

    it("verify that a user can withdraw funds from multiple units", async function() {
        let poolPrediction = await initPredictionWithOutcomes();
        await poolPrediction.publish({from: predictionOperator});
        
        await initPlayers(poolPrediction.address);
        await poolPrediction.buyUnit(1000, 1, {from: player1});
        await poolPrediction.buyUnit(2000, 2, {from: player2});
        await poolPrediction.buyUnit(2000, 1, {from: player3});
        await poolPrediction.buyUnit(1000, 1, {from: player3});

        await poolPrediction.pause({from: predictionOperator});
        await poolPrediction.setUnitBuyingEndTime(nowInSeconds - 1000, {from: predictionOperator});
        await poolPrediction.publish({from: predictionOperator});
        await oracle.registerPrediction(poolPrediction.address, {from: oracleOperator});
        await oracle.setOutcome(poolPrediction.address, 1, {from: oracleOperator});

        await poolPrediction.resolve({from: predictionOperator});

        await poolPrediction.withdrawUnits({from: player3});

        let player3Tokens = await stoxTestToken.balanceOf(player3);
        let tokenPool = await poolPrediction.tokenPool.call();
        let predictionTokens = await stoxTestToken.balanceOf.call(poolPrediction.address);

        assert.equal(player3Tokens, 4500);
        assert.equal(predictionTokens, 1500);
    });

    it("verify that a user can withdraw funds from multiple units in bulks", async function() {
        let poolPrediction = await initPredictionWithOutcomes();
        await poolPrediction.publish({from: predictionOperator});
        
        await initPlayers(poolPrediction.address);
        await poolPrediction.buyUnit(1000, 1, {from: player1});
        await poolPrediction.buyUnit(2000, 2, {from: player2});
        await poolPrediction.buyUnit(2000, 1, {from: player3});
        await poolPrediction.buyUnit(1000, 1, {from: player3});

        await poolPrediction.pause({from: predictionOperator});
        await poolPrediction.setUnitBuyingEndTime(nowInSeconds - 1000, {from: predictionOperator});
        await poolPrediction.publish({from: predictionOperator});
        await oracle.registerPrediction(poolPrediction.address, {from: oracleOperator});
        await oracle.setOutcome(poolPrediction.address, 1, {from: oracleOperator});

        await poolPrediction.resolve({from: predictionOperator});

        // Withdraw 1st unit
        await poolPrediction.withdrawUnitsBulk(0,1, {from: player3});

        let player3Tokens = await stoxTestToken.balanceOf(player3);
        let tokenPool = await poolPrediction.tokenPool.call();
        let predictionTokens = await stoxTestToken.balanceOf.call(poolPrediction.address);

        assert.equal(player3Tokens, 3000);
        assert.equal(predictionTokens, 3000);

        // Withdraw 2nd unit
        await poolPrediction.withdrawUnitsBulk(1,1, {from: player3});

        player3Tokens = await stoxTestToken.balanceOf(player3);
        tokenPool = await poolPrediction.tokenPool.call();
        predictionTokens = await stoxTestToken.balanceOf.call(poolPrediction.address);

        assert.equal(player3Tokens, 4500);
        assert.equal(predictionTokens, 1500);
    });

    it("verify that the operator can pay all users after the prediction is resolved", async function() {
        let poolPrediction = await initPredictionWithOutcomes();
        await poolPrediction.publish({from: predictionOperator});
        
        await initPlayers(poolPrediction.address);
        await poolPrediction.buyUnit(1000, 1, {from: player1});
        await poolPrediction.buyUnit(2000, 2, {from: player2});
        await poolPrediction.buyUnit(3000, 1, {from: player3});

        await poolPrediction.pause({from: predictionOperator});
        await poolPrediction.setUnitBuyingEndTime(nowInSeconds - 1000, {from: predictionOperator});
        await poolPrediction.publish({from: predictionOperator});
        await oracle.registerPrediction(poolPrediction.address, {from: oracleOperator});
        await oracle.setOutcome(poolPrediction.address, 1, {from: oracleOperator});

        await poolPrediction.resolve({from: predictionOperator});

        await poolPrediction.payAllUnits({from: predictionOperator});

        let player1Tokens = await stoxTestToken.balanceOf(player1);
        let player3Tokens = await stoxTestToken.balanceOf(player3);
        let tokenPool = await poolPrediction.tokenPool.call();
        let predictionTokens = await stoxTestToken.balanceOf.call(poolPrediction.address);

        assert.equal(player1Tokens, 1500);
        assert.equal(player3Tokens, 4500);
        assert.equal(predictionTokens, 0);
    });

    it("verify that the operator can pay all users in bulks after the prediction is resolved", async function() {
        let poolPrediction = await initPredictionWithOutcomes();
        await poolPrediction.publish({from: predictionOperator});
        
        await initPlayers(poolPrediction.address);
        await poolPrediction.buyUnit(1000, 1, {from: player1});
        await poolPrediction.buyUnit(2000, 2, {from: player2});
        await poolPrediction.buyUnit(2000, 1, {from: player3});
        await poolPrediction.buyUnit(1000, 1, {from: player3});

        await poolPrediction.pause({from: predictionOperator});
        await poolPrediction.setUnitBuyingEndTime(nowInSeconds - 1000, {from: predictionOperator});
        await poolPrediction.publish({from: predictionOperator});
        await oracle.registerPrediction(poolPrediction.address, {from: oracleOperator});
        await oracle.setOutcome(poolPrediction.address, 1, {from: oracleOperator});

        await poolPrediction.resolve({from: predictionOperator});

        await poolPrediction.payAllUnitsBulk(0, 3, {from: predictionOperator});

        let player1Tokens = await stoxTestToken.balanceOf(player1);
        let player3Tokens = await stoxTestToken.balanceOf(player3);
        let tokenPool = await poolPrediction.tokenPool.call();
        let predictionTokens = await stoxTestToken.balanceOf.call(poolPrediction.address);

        assert.equal(player1Tokens, 1500);
        assert.equal(player3Tokens, 3000);
        assert.equal(predictionTokens, 1500);

        await poolPrediction.payAllUnitsBulk(3, 1, {from: predictionOperator});

        player1Tokens = await stoxTestToken.balanceOf(player1);
        player3Tokens = await stoxTestToken.balanceOf(player3);
        tokenPool = await poolPrediction.tokenPool.call();
        predictionTokens = await stoxTestToken.balanceOf.call(poolPrediction.address);

        assert.equal(player1Tokens, 1500);
        assert.equal(player3Tokens, 4500);
        assert.equal(predictionTokens, 0);
    });

    it("verify that the prediction can be canceled", async function() {
        let poolPrediction = await initPredictionWithOutcomes();
        await poolPrediction.publish({from: predictionOperator});
        await poolPrediction.cancel({from: predictionOperator});
        
        predictionStatus = await poolPrediction.status.call();
        assert.equal(predictionStatus, 4);
    });

    it("verify that a operator can refund a user after the prediction is canceled", async function() {
        let poolPrediction = await initPredictionWithOutcomes();
        await poolPrediction.publish({from: predictionOperator});

        await initPlayers(poolPrediction.address);
        await poolPrediction.buyUnit(1000, 1, {from: player1});
        await poolPrediction.buyUnit(2000, 2, {from: player2});
        await poolPrediction.buyUnit(3000, 1, {from: player3});

        await poolPrediction.cancel({from: predictionOperator});
        await poolPrediction.refundUser(player1, 1, {from: predictionOperator});

        let player1Tokens = await stoxTestToken.balanceOf(player1);
        let tokenPool = await poolPrediction.tokenPool.call();
        let predictionTokens = await stoxTestToken.balanceOf.call(poolPrediction.address);

        assert.equal(player1Tokens, 1000);
        assert.equal(tokenPool, 5000);
        assert.equal(predictionTokens, 5000);
    });

    it("verify that a user can get a refund after the prediction is canceled", async function() {
        let poolPrediction = await initPredictionWithOutcomes();
        await poolPrediction.publish({from: predictionOperator});

        await initPlayers(poolPrediction.address);
        await poolPrediction.buyUnit(1000, 1, {from: player1});
        await poolPrediction.buyUnit(2000, 2, {from: player2});
        await poolPrediction.buyUnit(3000, 1, {from: player3});

        await poolPrediction.cancel({from: predictionOperator});
        await poolPrediction.getRefund(1, {from: player1});

        let player1Tokens = await stoxTestToken.balanceOf(player1);
        let tokenPool = await poolPrediction.tokenPool.call();
        let predictionTokens = await stoxTestToken.balanceOf.call(poolPrediction.address);

        assert.equal(player1Tokens, 1000);
        assert.equal(tokenPool, 5000);
        assert.equal(predictionTokens, 5000);
    });

    it("verify that a operator can refund all users after the prediction is canceled", async function() {
        let poolPrediction = await initPredictionWithOutcomes();
        await poolPrediction.publish({from: predictionOperator});

        await initPlayers(poolPrediction.address);
        await poolPrediction.buyUnit(1000, 1, {from: player1});
        await poolPrediction.buyUnit(2000, 2, {from: player2});
        await poolPrediction.buyUnit(3000, 1, {from: player3});

        await poolPrediction.cancel({from: predictionOperator});
        await poolPrediction.refundAllUsers({from: predictionOperator});

        let player1Tokens = await stoxTestToken.balanceOf(player1);
        let player2Tokens = await stoxTestToken.balanceOf(player2);
        let player3Tokens = await stoxTestToken.balanceOf(player3);
        let tokenPool = await poolPrediction.tokenPool.call();
        let predictionTokens = await stoxTestToken.balanceOf.call(poolPrediction.address);

        assert.equal(player1Tokens, 1000);
        assert.equal(player2Tokens, 2000);
        assert.equal(player3Tokens, 3000);
        assert.equal(tokenPool, 0);
        assert.equal(predictionTokens, 0);
    });

    it("verify that an prediction can be paused", async function() {
        let poolPrediction = await initPredictionWithOutcomes();
        await poolPrediction.publish({from: predictionOperator});
        await poolPrediction.pause({from: predictionOperator});
        
        predictionStatus = await poolPrediction.status.call();
        assert.equal(predictionStatus, 3);
    });
});
