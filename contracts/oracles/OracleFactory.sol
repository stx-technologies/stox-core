pragma solidity ^0.4.18;
import "./IOracleFactoryImpl.sol";
import "../Ownable.sol";

/*
    @title OracleFactory contract - A factory contract for generating oracles.
    It holds a factory interface object so we can update the oracle code without deploying a new oracle factory to the ethereum netowrk.
 */
contract OracleFactory is Ownable {
    event OracleCreated(address indexed _creator, address _oracle);

    IOracleFactoryImpl public factory;

    function OracleFactory(IOracleFactoryImpl _factory) public Ownable(msg.sender) {
        factory = _factory;
    }

    function setFactory(IOracleFactoryImpl _factory) public ownerOnly {
        require ((address(_factory) != address(this)) && (address(_factory) != 0x0));

        factory = _factory;
    }

    function createOracle(string _name) public returns(address) {
        address oracle = factory.createOracle(msg.sender, _name);

        OracleCreated(msg.sender, oracle);
        return (oracle);
    }
}