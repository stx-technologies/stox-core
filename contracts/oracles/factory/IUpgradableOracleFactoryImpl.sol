pragma solidity ^0.4.23;

/*
    @title IUpgradableOracleFactoryImpl contract - An interface contract for the upgradable oracles factory.
 */
contract IUpgradableOracleFactoryImpl {
    function createMultipleOutcomeOracle(string _name) public;
    function createScalarOracle(string _name) public;
    event MultipleOutcomeOracleCreated(address indexed _creator, address indexed _newOracle);
    event ScalarOracleCreated(address indexed _creator, address indexed _newOracle);
}

