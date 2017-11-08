pragma solidity ^0.4.18;

/**
    @title IOracleFactoryImpl contract - A interface contract for the oracles factory.

    @author Danny Hellman - <danny@stox.com>
 */
contract IOracleFactoryImpl {
    function createOracle(address _owner, string _name) public returns(address); 
}