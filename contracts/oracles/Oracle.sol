pragma solidity ^0.4.18;
import "../Ownable.sol";
import "../Utils.sol";

contract Oracle is Ownable, Utils {

    event OutcomeAssigned(address indexed _eventAddress, uint indexed _outcomeId);
    event EventRegistered(address indexed _eventAddress);
    event EventUnregistered(address indexed _eventAddress);
    event OracleNameChanged(string _newName);

    string version = "0.1";
    string public name;
    mapping(address=>address) public events;
    mapping(address=>uint) public eventOutcome;

    function Oracle(address _owner, string _name) public Ownable(_owner) {
        name = _name;
    }

    function registerEvent(address _eventToRegister) public validAddress(_eventToRegister) ownerOnly {
        events[_eventToRegister] = _eventToRegister;

        EventRegistered(_eventToRegister);
    }

    function unRegisterEvent(address _eventToRegister) public ownerOnly {
        delete events[_eventToRegister];

        EventUnregistered(_eventToRegister);
    }

    // TODO: Set outcome should not immediately call event.setWinningOutcome, as we don't want accidential results to trigger events winnings
    function setOutcome (address _eventAddress, uint _outcomeId) 
            public 
            validAddress(_eventAddress)
            ownerOnly {
        
        require((_outcomeId != 0) && (address(events[_eventAddress]) != 0));
        eventOutcome[_eventAddress] = _outcomeId;
        
        OutcomeAssigned(_eventAddress, _outcomeId);
    }

    function getOutcome(address _eventAddress) public constant returns (uint) {
        require(address(events[_eventAddress]) != 0);

        return eventOutcome[_eventAddress];
    }

    function setName(string _newName) external ownerOnly {
        name = _newName;
        OracleNameChanged(_newName);
    }
}
