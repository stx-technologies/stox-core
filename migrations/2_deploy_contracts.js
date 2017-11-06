var EventFactory    = artifacts.require("./events/EventFactory.sol");
var OracleFactory   = artifacts.require("./oracles/OracleFactory.sol");

module.exports = function(deployer) {
    deployer.deploy(EventFactory);
    deployer.deploy(OracleFactory);
};
