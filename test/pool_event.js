const utils = require('./helpers/Utils');

const StoxTestToken = artifacts.require("./token/StoxTestToken.sol");
artifacts.require("./events/PoolEvent.sol");
const PoolEvent = artifacts.require("./events/PoolEvent.sol");
const EventFactory = artifacts.require("./events/EventFactory.sol");
const EventFactoryImpl = artifacts.require("./events/EventFactoryImpl.sol");
const Oracle = artifacts.require("./oracles/Oracle.sol");
const OracleFactory = artifacts.require("./oracles/OracleFactory.sol");
const OracleFactoryImpl = artifacts.require("./oracles/OracleFactoryImpl.sol");

let stoxTestToken;
let eventFactory;
let eventFactoryImpl;
let oracleFactory;
let oracleFactoryImpl;
let oracle;

// Accounts
let eventOperator;
let oracleOperator;
let player1;
let player2;
let player3;

function getLogArg(result, arg, logIndex = 0) {
    return result.logs[logIndex].args[arg];
}

function verifyItem(item, id, outcomeId, tokens, isWithdrawn, ownerAddress) {
    assert.equal(item[0], id);
    assert.equal(item[1], outcomeId);
    assert.equal(item[2], tokens);
    assert.equal(item[3], isWithdrawn);
    assert.equal(item[4], ownerAddress);
}

contract('PoolEvent', function(accounts) {

    let factoryOperator = accounts[0];
    let oracleOperator  = accounts[1];
    let eventOperator   = accounts[2];
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

    async function initEvent() {
        let poolEvent;
        await eventFactory.createPoolEvent(oracle.address, tommorowInSeconds, tommorowInSeconds, "Test Event", {from: eventOperator}).then(function(result) {
            poolEvent = PoolEvent.at(getLogArg(result, "_newEvent"));
        });

        return poolEvent;
    }

    async function initEventWithOutcomes(event) {
        let poolEvent = await initEvent();

        await poolEvent.addOutcome("o1", {from: eventOperator});
        await poolEvent.addOutcome("o2", {from: eventOperator});
        await poolEvent.addOutcome("o3", {from: eventOperator});

        return poolEvent;
    }

    async function initPlayers(eventAddress) {
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

        // Allow event to use tokens so players can buy items
        await stoxTestToken.approve(eventAddress, 0, {from: player1});
        await stoxTestToken.approve(eventAddress, 0, {from: player2});
        await stoxTestToken.approve(eventAddress, 0, {from: player3});
        
        await stoxTestToken.approve(eventAddress, 1000, {from: player1});
        await stoxTestToken.approve(eventAddress, 2000, {from: player2});
        await stoxTestToken.approve(eventAddress, 3000, {from: player3});

        let apporovedTokens = await stoxTestToken.allowance.call(player1, eventAddress);
    }

    before(async function() {
        // runs before all tests in this block
        stoxTestToken = await StoxTestToken.new("Stox Text", "STX", 18);
        
        oracleFactoryImpl = await OracleFactoryImpl.new()
        oracleFactory = await OracleFactory.new(oracleFactoryImpl.address, {from: factoryOperator});
        
        eventFactoryImpl = await EventFactoryImpl.new(stoxTestToken.address);
        eventFactory = await EventFactory.new(eventFactoryImpl.address, {from: factoryOperator})

        var tomorrow = new Date();
        tomorrow.setDate((new Date).getDate() + 1);
        tommorowInSeconds = Math.round(tomorrow.getTime() / 1000);
        nowInSeconds = Math.round((new Date()).getTime() / 1000);

        await initOracle();
      });

    it("should throw if event name is invalid", async function() {
        await eventFactory.createPoolEvent(oracle.address, tommorowInSeconds, tommorowInSeconds, "Test Event", {from: eventOperator}).then(function(result) {
            poolEvent = PoolEvent.at(getLogArg(result, "_newEvent"));
        });

        let name = await poolEvent.name.call();

        assert.equal(name, "Test Event");
     });

    it("should throw if oracle address is invalid", async function() {
        try {
            await eventFactory.createPoolEvent(0, tommorowInSeconds, tommorowInSeconds, "Test Event", {from: eventOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if event end time is invalid", async function() {
        try {
            await eventFactory.createPoolEvent(oracle.address, 0, tommorowInSeconds, "Test Event", {from: eventOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if items buying end time is invalid", async function() {
        try {
            await eventFactory.createPoolEvent(oracle.address, tommorowInSeconds, 0, "Test Event", {from: eventOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if items buying end time is invalid", async function() {
        try {
            await eventFactory.createPoolEvent(oracle.address, tommorowInSeconds, 0, "Test Event", {from: eventOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if event end time < items buying end time", async function() {
        try {
            await eventFactory.createPoolEvent(oracle.address, tommorowInSeconds, (tommorowInSeconds + 1000), "Test Event", {from: eventOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if outcome name is invalid", async function() {
        let poolEvent = await initEvent();
        
        try {
            await poolEvent.addOutcome("", {from: eventOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if a non owner added outcome", async function() {
        let poolEvent = await initEvent();

        try {
            await poolEvent.addOutcome("outcome1", {from: player1});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("verify that the owner can add an outcome", async function() {
        let poolEvent = await initEvent();
        await poolEvent.addOutcome("outcome1", {from: eventOperator});
        let outcomeName = await poolEvent.getOutcome(1);
        
        assert.equal(outcomeName, "outcome1");
    });

    it("should throw if event is published without outcomes", async function() {
        let poolEvent = await initEvent();

        try {
            await poolEvent.publish({from: eventOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if event is published with 1 outcome", async function() {
        let poolEvent = await initEvent();

        await poolEvent.addOutcome("outcome1", {from: eventOperator});
        try {
            await poolEvent.publish({from: eventOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if a non owner publish the event", async function() {
        let poolEvent = await initEventWithOutcomes();

        try {
            await poolEvent.publish({from: player1});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("verify that the owner published the event", async function() {
        let poolEvent = await initEventWithOutcomes();

        await poolEvent.publish({from: eventOperator});
        let eventStatus = await poolEvent.status.call();
        assert.equal(eventStatus, 1);
    });

    it("should throw if an already published event is published", async function() {
        let poolEvent = await initEventWithOutcomes();
        await poolEvent.publish({from: eventOperator});

        try {
            await poolEvent.publish({from: eventOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if a canceled event is published", async function() {
        let poolEvent = await initEventWithOutcomes();
        await poolEvent.publish({from: eventOperator});
        await poolEvent.cancel({from: eventOperator});

        try {
            await poolEvent.publish({from: eventOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("verify that a paused event can be published", async function() {
        let poolEvent = await initEventWithOutcomes();
        await poolEvent.publish({from: eventOperator});
        await poolEvent.pause({from: eventOperator});
        let eventStatus = await poolEvent.status.call();
        assert.equal(eventStatus, 3);

        await poolEvent.publish({from: eventOperator});
        eventStatus = await poolEvent.status.call();
        assert.equal(eventStatus, 1);
    });

    it("verify that the items buying end time can be changed when event is initializing", async function() {
        let poolEvent = await initEvent();

        await poolEvent.setItemBuyingEndTime(tommorowInSeconds - 1000, {from: eventOperator});
        let itemBuyingEndTimeSeconds = await poolEvent.itemBuyingEndTimeSeconds.call();
        assert.equal(itemBuyingEndTimeSeconds, tommorowInSeconds - 1000);
    });

    it("verify that the items buying end time can be changed when event is paused", async function() {
        let poolEvent = await initEventWithOutcomes();
        await poolEvent.publish({from: eventOperator});
        await poolEvent.pause({from: eventOperator});

        await poolEvent.setItemBuyingEndTime(tommorowInSeconds - 1000, {from: eventOperator});
        let itemBuyingEndTimeSeconds = await poolEvent.itemBuyingEndTimeSeconds.call();
        assert.equal(itemBuyingEndTimeSeconds, tommorowInSeconds - 1000);
    });

    it("should throw if items buying end time is changed when event is published", async function() {
        let poolEvent = await initEventWithOutcomes();
        await poolEvent.publish({from: eventOperator});

        try {
            await poolEvent.setItemBuyingEndTime(tommorowInSeconds - 1000, {from: eventOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if a non owner changes items buying end time", async function() {
        let poolEvent = await initEvent();

        try {
            await poolEvent.setItemBuyingEndTime(tommorowInSeconds - 1000, {from: player1});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("verify that the event end time can be changed when event is initializing", async function() {
        let poolEvent = await initEvent();

        await poolEvent.setEventEndTime(tommorowInSeconds + 1000, {from: eventOperator});
        let eventEndTimeSeconds = await poolEvent.eventEndTimeSeconds.call();
        assert.equal(eventEndTimeSeconds, tommorowInSeconds + 1000);
    });

    it("verify that the event end time can be changed when event is paused", async function() {
        let poolEvent = await initEventWithOutcomes();
        await poolEvent.publish({from: eventOperator});
        await poolEvent.pause({from: eventOperator});

        await poolEvent.setEventEndTime(tommorowInSeconds + 1000, {from: eventOperator});
        let eventEndTimeSeconds = await poolEvent.eventEndTimeSeconds.call();
        assert.equal(eventEndTimeSeconds, tommorowInSeconds + 1000);
    });

    it("should throw if a non owner changes event end time", async function() {
        let poolEvent = await initEvent();

        try {
            await poolEvent.setEventEndTime(tommorowInSeconds + 1000, {from: player1});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("verify that the event name can be changed", async function() {
        let poolEvent = await initEvent();

        await poolEvent.setEventName("new name", {from: eventOperator});
        let eventName = await poolEvent.name.call();
        assert.equal(eventName, "new name");
    });

    it("should throw if a non owner changes event name", async function() {
        let poolEvent = await initEvent();

        try {
            await poolEvent.setEventName("new name", {from: player1});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("verify that the oracle can be changed", async function() {
        let poolEvent = await initEvent();
        let newOracle;

        await oracleFactory.createOracle("Test Oracle", {from: oracleOperator}).then(function(result) {
            newOracle = Oracle.at(getLogArg(result, "_oracle"));
        });

        await poolEvent.setOracle(newOracle.address, {from: eventOperator});
        let oracleAddress = await poolEvent.oracleAddress.call();
        assert.equal(oracleAddress, newOracle.address);
    });

    it("verify that a user can buy an item", async function() {
        let poolEvent = await initEventWithOutcomes();
        await poolEvent.publish({from: eventOperator});
        await initPlayers(poolEvent.address);

        await poolEvent.buyItem(1000, 1, {from: player1});
        let item = await poolEvent.items.call(0);
        verifyItem(item, 1, 1, 1000, false, player1);

        let tokenPool = await poolEvent.tokenPool.call();
        let eventTokens = await stoxTestToken.balanceOf.call(poolEvent.address);

        assert.equal(tokenPool, 1000);
        assert.equal(eventTokens, 1000);
    });

    it("verify that multiple users can buy items", async function() {
        let poolEvent = await initEventWithOutcomes();
        await poolEvent.publish({from: eventOperator});
        await initPlayers(poolEvent.address);

        await poolEvent.buyItem(1000, 1, {from: player1});
        await poolEvent.buyItem(2000, 2, {from: player2});
        await poolEvent.buyItem(3000, 1, {from: player3});

        let item;
        item = await poolEvent.items.call(0);
        verifyItem(item, 1, 1, 1000, false, player1);
        item = await poolEvent.items.call(1);
        verifyItem(item, 2, 2, 2000, false, player2);
        item = await poolEvent.items.call(2);
        verifyItem(item, 3, 1, 3000, false, player3);

        let tokenPool = await poolEvent.tokenPool.call();
        let eventTokens = await stoxTestToken.balanceOf.call(poolEvent.address);

        assert.equal(tokenPool, 6000);
        assert.equal(eventTokens, 6000);
    });

    it("should throw if trying to resolve an event before oracle has been set", async function() {
        let poolEvent = await initEventWithOutcomes();
        await poolEvent.publish({from: eventOperator});
        await initPlayers(poolEvent.address);
        await poolEvent.buyItem(1000, 1, {from: player1});
        await poolEvent.buyItem(2000, 2, {from: player2});
        await poolEvent.buyItem(3000, 1, {from: player3});

        await poolEvent.pause({from: eventOperator});
        await poolEvent.setItemBuyingEndTime(nowInSeconds - 1000, {from: eventOperator});
        await poolEvent.publish({from: eventOperator});

        try {
            await poolEvent.resolve({from: eventOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("should throw if trying to resolve an event before items buying time has ended", async function() {
        let poolEvent = await initEventWithOutcomes();
        await poolEvent.publish({from: eventOperator});
        await initPlayers(poolEvent.address);
        await poolEvent.buyItem(1000, 1, {from: player1});
        await poolEvent.buyItem(2000, 2, {from: player2});
        await poolEvent.buyItem(3000, 1, {from: player3});

        await oracle.registerEvent(poolEvent.address, {from: oracleOperator});
        await oracle.setOutcome(poolEvent.address, 1, {from: oracleOperator});

        try {
            await poolEvent.resolve({from: eventOperator});
        } catch (error) {
            return utils.ensureException(error);
        }

        assert.equal(false, "Didn't throw");
    });

    it("verify that an event can be resolved", async function() {
        let poolEvent = await initEventWithOutcomes();
        await poolEvent.publish({from: eventOperator});
        
        await initPlayers(poolEvent.address);
        await poolEvent.buyItem(1000, 1, {from: player1});
        await poolEvent.buyItem(2000, 2, {from: player2});
        await poolEvent.buyItem(3000, 1, {from: player3});

        await poolEvent.pause({from: eventOperator});
        await poolEvent.setItemBuyingEndTime(nowInSeconds - 1000, {from: eventOperator});
        await poolEvent.publish({from: eventOperator});
        await oracle.registerEvent(poolEvent.address, {from: oracleOperator});
        await oracle.setOutcome(poolEvent.address, 1, {from: oracleOperator});

        await poolEvent.resolve({from: eventOperator});

        eventStatus = await poolEvent.status.call();
        assert.equal(eventStatus, 2);

        let winnigOutcome = await poolEvent.winningOutcomeId.call();
        assert.equal(winnigOutcome, 1);

        let player1Winnings = await poolEvent.calculateUserItemsWithdrawValue(player1);
        let player2Winnings = await poolEvent.calculateUserItemsWithdrawValue(player2);
        let player3Winnings = await poolEvent.calculateUserItemsWithdrawValue(player3);

        assert.equal(player1Winnings, 1500);
        assert.equal(player2Winnings, 0);
        assert.equal(player3Winnings, 4500);
    });

    it("verify that a user can withdraw funds from an item", async function() {
        let poolEvent = await initEventWithOutcomes();
        await poolEvent.publish({from: eventOperator});
        
        await initPlayers(poolEvent.address);
        await poolEvent.buyItem(1000, 1, {from: player1});
        await poolEvent.buyItem(2000, 2, {from: player2});
        await poolEvent.buyItem(3000, 1, {from: player3});

        await poolEvent.pause({from: eventOperator});
        await poolEvent.setItemBuyingEndTime(nowInSeconds - 1000, {from: eventOperator});
        await poolEvent.publish({from: eventOperator});
        await oracle.registerEvent(poolEvent.address, {from: oracleOperator});
        await oracle.setOutcome(poolEvent.address, 1, {from: oracleOperator});

        await poolEvent.resolve({from: eventOperator});

        await poolEvent.withdrawItems({from: player1});

        let player1Tokens = await stoxTestToken.balanceOf(player1);
        let tokenPool = await poolEvent.tokenPool.call();
        let eventTokens = await stoxTestToken.balanceOf.call(poolEvent.address);

        assert.equal(player1Tokens, 1500);
        assert.equal(eventTokens, 4500);
    });

    it("verify that the operator can pay all users after the event is resolved", async function() {
        let poolEvent = await initEventWithOutcomes();
        await poolEvent.publish({from: eventOperator});
        
        await initPlayers(poolEvent.address);
        await poolEvent.buyItem(1000, 1, {from: player1});
        await poolEvent.buyItem(2000, 2, {from: player2});
        await poolEvent.buyItem(3000, 1, {from: player3});

        await poolEvent.pause({from: eventOperator});
        await poolEvent.setItemBuyingEndTime(nowInSeconds - 1000, {from: eventOperator});
        await poolEvent.publish({from: eventOperator});
        await oracle.registerEvent(poolEvent.address, {from: oracleOperator});
        await oracle.setOutcome(poolEvent.address, 1, {from: oracleOperator});

        await poolEvent.resolve({from: eventOperator});

        await poolEvent.payAllItems({from: eventOperator});

        let player1Tokens = await stoxTestToken.balanceOf(player1);
        let player3Tokens = await stoxTestToken.balanceOf(player3);
        let tokenPool = await poolEvent.tokenPool.call();
        let eventTokens = await stoxTestToken.balanceOf.call(poolEvent.address);

        assert.equal(player1Tokens, 1500);
        assert.equal(player3Tokens, 4500);
        assert.equal(eventTokens, 0);
    });

    it("verify that the event can be canceled", async function() {
        let poolEvent = await initEventWithOutcomes();
        await poolEvent.publish({from: eventOperator});
        await poolEvent.cancel({from: eventOperator});
        
        eventStatus = await poolEvent.status.call();
        assert.equal(eventStatus, 4);
    });

    it("verify that a operator can refund a user after the event is canceled", async function() {
        let poolEvent = await initEventWithOutcomes();
        await poolEvent.publish({from: eventOperator});

        await initPlayers(poolEvent.address);
        await poolEvent.buyItem(1000, 1, {from: player1});
        await poolEvent.buyItem(2000, 2, {from: player2});
        await poolEvent.buyItem(3000, 1, {from: player3});

        await poolEvent.cancel({from: eventOperator});
        await poolEvent.refundUser(player1, {from: eventOperator});

        let player1Tokens = await stoxTestToken.balanceOf(player1);
        let tokenPool = await poolEvent.tokenPool.call();
        let eventTokens = await stoxTestToken.balanceOf.call(poolEvent.address);

        assert.equal(player1Tokens, 1000);
        assert.equal(tokenPool, 5000);
        assert.equal(eventTokens, 5000);
    });

    it("verify that a user can get a refund after the event is canceled", async function() {
        let poolEvent = await initEventWithOutcomes();
        await poolEvent.publish({from: eventOperator});

        await initPlayers(poolEvent.address);
        await poolEvent.buyItem(1000, 1, {from: player1});
        await poolEvent.buyItem(2000, 2, {from: player2});
        await poolEvent.buyItem(3000, 1, {from: player3});

        await poolEvent.cancel({from: eventOperator});
        await poolEvent.getRefund({from: player1});

        let player1Tokens = await stoxTestToken.balanceOf(player1);
        let tokenPool = await poolEvent.tokenPool.call();
        let eventTokens = await stoxTestToken.balanceOf.call(poolEvent.address);

        assert.equal(player1Tokens, 1000);
        assert.equal(tokenPool, 5000);
        assert.equal(eventTokens, 5000);
    });

    it("verify that a operator can refund all users after the event is canceled", async function() {
        let poolEvent = await initEventWithOutcomes();
        await poolEvent.publish({from: eventOperator});

        await initPlayers(poolEvent.address);
        await poolEvent.buyItem(1000, 1, {from: player1});
        await poolEvent.buyItem(2000, 2, {from: player2});
        await poolEvent.buyItem(3000, 1, {from: player3});

        await poolEvent.cancel({from: eventOperator});
        await poolEvent.refundAllUsers({from: eventOperator});

        let player1Tokens = await stoxTestToken.balanceOf(player1);
        let player2Tokens = await stoxTestToken.balanceOf(player2);
        let player3Tokens = await stoxTestToken.balanceOf(player3);
        let tokenPool = await poolEvent.tokenPool.call();
        let eventTokens = await stoxTestToken.balanceOf.call(poolEvent.address);

        assert.equal(player1Tokens, 1000);
        assert.equal(player2Tokens, 2000);
        assert.equal(player3Tokens, 3000);
        assert.equal(tokenPool, 0);
        assert.equal(eventTokens, 0);
    });

    it("verify that an event can be paused", async function() {
        let poolEvent = await initEventWithOutcomes();
        await poolEvent.publish({from: eventOperator});
        await poolEvent.pause({from: eventOperator});
        
        eventStatus = await poolEvent.status.call();
        assert.equal(eventStatus, 3);
    });
});
