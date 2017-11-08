pragma solidity ^0.4.18;
import "./IEventFactoryImpl.sol";
import "../Ownable.sol";

/**
    @title EventFactory contract - A factory contract for generating events.
    It holds a factory interface object so we can update the event code without deploying a new event factory to the ethereum netowrk.

    @author Danny Hellman - <danny@stox.com>
 */
contract EventFactory is Ownable {

    event PoolEventCreated(address indexed _creator, address indexed _newEvent);
    
    IEventFactoryImpl public factory;

    function EventFactory(IEventFactoryImpl _factory) public Ownable(msg.sender) {
        factory = _factory;
    }

    function setFactory(IEventFactoryImpl _factory) public ownerOnly {
        require ((address(_factory) != address(this)) && (address(_factory) != 0x0));

        factory = _factory;
    }

    function createPoolEvent(address _oracle, uint _eventEndTimeSeconds, uint _optionBuyingEndTimeSeconds, string _name) public returns(address) {
        address newEvent = factory.createPoolEvent(msg.sender, _oracle, _eventEndTimeSeconds, _optionBuyingEndTimeSeconds, _name);

        PoolEventCreated(msg.sender, newEvent);
        return (address(newEvent));
    }
}