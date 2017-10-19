pragma solidity ^0.4.0;
import "../Ownable.sol";

contract Oracle is Ownable {

    event OnOutcomeAssigned(address indexed eventAddress, uint indexed outcomeId);
    event OnEventRegistered(address indexed eventAddress);
    event OnEventUnregistered(address indexed eventAddress);

    string version = "0.1";
    string public name;
    mapping(address=>address) public events;
    mapping(address=>uint) public eventOutcome;

    function Oracle(address _owner, string _name) public Ownable(_owner) {
        name = _name;
    }

    function registerEvent(address _eventToRegister) public ownerOnly {
        events[_eventToRegister] = _eventToRegister;

        OnEventRegistered(_eventToRegister);
    }

    function unRegisterEvent(address _eventToRegister) public ownerOnly {
        delete events[_eventToRegister];

        OnEventUnregistered(_eventToRegister);
    }

    // TODO: Set outcome should not immediately call event.setWinningOutcome, as we don't want accidential results to trigger events winnings
    function setOutcome (address _eventAddress, uint _outcomeId) public ownerOnly {
        require((_outcomeId != 0) && (address(events[_eventAddress]) != 0));
        eventOutcome[_eventAddress] = _outcomeId;
        
        OnOutcomeAssigned(_eventAddress, _outcomeId);
    }

    function getOutcome(address _eventAddress) public returns (uint) {
        require(address(events[_eventAddress]) != 0);

        return eventOutcome[_eventAddress];
    }
}
