pragma solidity ^0.4.18;

/*
    @title IOracleFactoryImpl contract - A interface contract for the oracles factory.
 */
contract IOracleFactoryImpl {
    function createOracle(address _owner, string _name) public returns(address); 
}
