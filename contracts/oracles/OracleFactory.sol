pragma solidity ^0.4.0;
import "../Ownable.sol";
import "./IOracleFactoryImpl.sol";

contract OracleFactory is Ownable {
    event OnOracleCreated(address indexed creator, address oracle);

    IOracleFactoryImpl public factory;

    function OracleFactory(IOracleFactoryImpl _factory) public Ownable(msg.sender) {
        factory = _factory;
    }

    function setFactory(IOracleFactoryImpl _factory) public {
        require ((address(_factory) != address(this)) && (address(_factory) != 0x0));

        factory = _factory;
    }

    function createOracle(string _name) public returns(address) {
        address oracle = factory.createOracle(msg.sender, _name);

        OnOracleCreated(msg.sender, oracle);
        return (oracle);
    }
}