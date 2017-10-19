pragma solidity ^0.4.0;
import "./Event.sol";
import "./IEventFactoryImpl.sol";

contract EventFactoryImpl is IEventFactoryImpl {

    function createEvent(address _owner, address _oracle, uint _eventEndTimeSeconds, uint _optionBuyingEndTimeSeconds, string _name) public returns(address) {
        Event newEvent = new Event(_owner, _oracle, _eventEndTimeSeconds, _optionBuyingEndTimeSeconds, _name);

        return (address(newEvent));
    }
}