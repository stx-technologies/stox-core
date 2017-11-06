pragma solidity ^0.4.18;

contract IOracleFactoryImpl {
    function createOracle(address _owner, string _name) public returns(address); 
}