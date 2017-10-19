var ConvertLib      = artifacts.require("./ConvertLib.sol");
var EventFactory    = artifacts.require("./events/EventFactory.sol");
var OracleFactory   = artifacts.require("./oracles/OracleFactory.sol");
var Ownable         = artifacts.require("./Ownable.sol");
var MetaCoin        = artifacts.require("./MetaCoin.sol");

module.exports = function(deployer) {
    //deployer.deploy(Ownable);
    //deployer.link(Ownable, [Event, OracleFactory]);
    
    deployer.deploy(EventFactory);
    //deployer.link(EventFactory, OracleFactory);
    
    deployer.deploy(OracleFactory);

    deployer.deploy(ConvertLib);
    deployer.link(ConvertLib, MetaCoin);
    deployer.deploy(MetaCoin);
};
