pragma solidity ^0.4.18;
import "./Oracle.sol";
import "./IOracleFactoryImpl.sol";

/*
    @title OracleFactoryImpl contract - The implementation for the Oracle Factory
 */
contract OracleFactoryImpl is IOracleFactoryImpl {

    function createOracle(address _owner, string _name) public returns(address) {
        Oracle oracle = new Oracle(_owner, _name);

        return (address(oracle));
    }
}