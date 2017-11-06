pragma solidity ^0.4.18;
import "./PoolEvent.sol";
import "./IEventFactoryImpl.sol";
import "../token/IERC20Token.sol";

contract EventFactoryImpl is IEventFactoryImpl {

    IERC20Token public stox;

    function EventFactoryImpl(IERC20Token _stox) public {
        stox = _stox;
    }

    function createPoolEvent(address _owner, address _oracle, uint _eventEndTimeSeconds, uint _optionBuyingEndTimeSeconds, string _name) public returns(address) {
        PoolEvent newEvent = new PoolEvent(_owner, _oracle, _eventEndTimeSeconds, _optionBuyingEndTimeSeconds, _name, stox);

        return (address(newEvent));
    }
}