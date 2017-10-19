const Event = artifacts.require("./events/Event.sol");
const EventFactory = artifacts.require("./events/EventFactory.sol");
const Oracle = artifacts.require("./oracles/Oracle.sol");
const OracleFactory = artifacts.require("./oracles/OracleFactory.sol");

let eventFactory;
let event;
let oracleFactory;
let oracle;


contract('Event', function(accounts) {

    it("Create Oracle", function() {
        return OracleFactory.deployed().then(function(instance) {
            oracleFactory = instance;
            return oracleFactory.createOracle("Cool Oracle");
        }).then(function(result) {
            for (var i = 0; i < result.logs.length; i++) {
                var log = result.logs[i];
        
                if (log.event == "OnOracleCreated") {
                  foundCreateOracle = true;
                  break;
                }
              }

            assert(foundCreateOracle, "We didn't find the created oracle");

            oracle = Oracle.at(result.logs[0].args["oracle"]);
            return oracle.getOracleName.call();
        }).then(function(name) {
            assert.equal(name, "Cool Oracle", "function returned " + name);
        });
      });

      it("Create Event with oracle", function() {
        return EventFactory.deployed().then(function(instance) {
            eventFactory = instance;
            return eventFactory.createEvent(oracle.address, 0, 0, "Cool Event");
        }).then(function(result) {
            for (var i = 0; i < result.logs.length; i++) {
                var log = result.logs[i];
        
                if (log.event == "OnEventCreated") {
                  foundCreateEvent = true;
                  break;
                }
              }

            assert(foundCreateEvent, "We didn't find the created event");

            event = Event.at(result.logs[0].args["newEvent"]);
            return event.getEventName.call();
        }).then(function(name) {
            assert.equal(name, "Cool Event", "function returned " + name);
        });
      });

      it("Add outcome 1 - \"Barcelona\"", function() {
            return event.getEventName.call();
        }).then(function(name) {
            assert.equal(name, "Cool Event", "function returned " + name);
      });

      /*it("Add outcome 1 - \"Barcelona\"", function() {
        return Event.deployed().then(function(instance) {
            eventFactory = instance;
            return eventFactory.createEvent(oracle.address, 0, 0, "Cool Event");
        }).then(function(result) {
            for (var i = 0; i < result.logs.length; i++) {
                var log = result.logs[i];
        
                if (log.event == "OnEventCreated") {
                  foundCreateEvent = true;
                  break;
                }
              }

            assert(foundCreateEvent, "We didn't find the created event");

            event = Event.at(result.logs[0].args["newEvent"]);
            return event.getEventName.call();
        }).then(function(name) {
            assert.equal(name, "Cool Event", "function returned " + name);
        });
      });

      it("Add outcome 1 - \"Barcelona\"", function() {
        return event.addOutcome("Barcelona").then(function(result) {
            return event.getOutcome.call(1);
        }).then(function(name) {
        return event.addOutcome("Barcelona").then(function(result) {
            return event.getOutcome.call(1);
        }).then(function(name) {
            assert.equal(name, "Barcelona", "function returned " + name);
        });
      });

    /*it("Add outcome to event",  function() {
        return OracleFactory.deployed().then(funtion(instance) {
            oracleFactory = instance;
            return oracleFactory.createOracle.call("aa");
        
        }).then(function(outCoinBalance) {
        }
        let oracleFactory = OracleFactory.deployed();
        oracle = oracleFactory.createOracle("aa");

        assert.equal("aa", oracle.mData);
    });*/

    /*before(function() {
        let timeOnSeconds = Math.floor(Date.now() / 1000);
        
        // create oracle
        oracle = await Oracle.new(null);
        
        // create event
        event = await Event.new(oracle.address, timeOnSeconds + 60000, timeOnSeconds + 60000, null);
        
    });

    it("Add outcome to event",  function() {
        assert.equal(event.addOutcome(null), 1)
        assert.equal(event.addOutcome(null), 2)
      });*/
});