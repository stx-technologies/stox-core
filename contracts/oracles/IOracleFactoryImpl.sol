pragma solidity ^0.4.0;

contract IOracleFactoryImpl {
    function createOracle(address _owner, string _name) public returns(address); 
}