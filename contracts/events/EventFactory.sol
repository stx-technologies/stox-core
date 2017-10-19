pragma solidity ^0.4.0;
import "./IEventFactoryImpl.sol";
import "../Ownable.sol";

contract EventFactory is Ownable {

    event OnEventCreated(address indexed creator, address indexed newEvent);
    
    IEventFactoryImpl public factory;

    function EventFactory(IEventFactoryImpl _factory) public Ownable(msg.sender) {
        factory = _factory;
    }

    function setFactory(IEventFactoryImpl _factory) public {
        require ((address(_factory) != address(this)) && (address(_factory) != 0x0));

        factory = _factory;
    }

    function createEvent(address _oracle, uint _eventEndTimeSeconds, uint _optionBuyingEndTimeSeconds, string _name) public returns(address) {
        address newEvent = factory.createEvent(msg.sender, _oracle, _eventEndTimeSeconds, _optionBuyingEndTimeSeconds, _name);

        OnEventCreated(msg.sender, newEvent);
        return (address(newEvent));
    }
}