pragma solidity ^0.4.18;
import "../types/Oracle.sol";
import "./IUpgradableOracleFactory.sol";

/*
    @title OracleFactoryImpl contract - The implementation for the Oracle Factory
 */
contract OracleFactoryImpl is IUpgradableOracleFactory {

    event OracleCreated(address indexed _creator, address indexed _newOracle);

    function OracleFactoryImpl() public {}

    /*
        @dev Create an Oracle instance

        @param _name       Oracle name
    */
    function createOracle(string _name) public {
        Oracle newOracle = new Oracle(msg.sender, _name);

        OracleCreated(msg.sender, address(newOracle));
    }
}
