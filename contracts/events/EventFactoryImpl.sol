pragma solidity ^0.4.0;
import "./Event.sol";
import "./IEventFactoryImpl.sol";
import "../token/IERC20Token.sol";

contract EventFactoryImpl is IEventFactoryImpl {

    IERC20Token public stox;

    function EventFactoryImpl(IERC20Token _stox) public {
        stox = _stox;
    }

    function createEvent(address _owner, address _oracle, uint _eventEndTimeSeconds, uint _optionBuyingEndTimeSeconds, string _name) public returns(address) {
        Event newEvent = new Event(_owner, _oracle, _eventEndTimeSeconds, _optionBuyingEndTimeSeconds, _name, stox);

        return (address(newEvent));
    }
}