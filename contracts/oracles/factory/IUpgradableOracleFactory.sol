pragma solidity ^0.4.18;

/*
    @title IOracleFactoryImpl contract - A interface contract for the oracles factory.
 */
contract IUpgradableOracleFactory {
    function createOracle(string _name) public; 
    event OracleCreated(address indexed _creator, address indexed _newOracle);
}
