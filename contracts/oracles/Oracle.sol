pragma solidity ^0.4.18;
import "../Ownable.sol";
import "../Utils.sol";

/*
    @title Oracle contract - Basic oracle implementation.
    The oracle can register events and set their outcomes.
 */
contract Oracle is Ownable, Utils {

    /*
     *  Events
     */
    event OutcomeAssigned(address indexed _eventAddress, uint indexed _outcomeId);
    event EventRegistered(address indexed _eventAddress);
    event EventUnregistered(address indexed _eventAddress);
    event OracleNameChanged(string _newName);

    /*
     *  Members
     */
    string                      public version = "0.1";
    string                      public name;
    mapping(address=>bool)      public events;          // An index of all the events registered for this oracle
    mapping(address=>uint)      public eventOutcome;    // Mapping of event -> outcomes

    /*
        @dev constructor

        @param _owner                       Oracle owner / operator
        @param _name                        Oracle name
    */
    function Oracle(address _owner, string _name) public Ownable(_owner) {
        name = _name;
    }

    /*
        @dev Allow the oracle owner to register an event

        @param _event Event address to register
    */
    function registerEvent(address _event) public validAddress(_event) ownerOnly {
        events[_event] = true;

        EventRegistered(_event);
    }

    /*
        @dev Allow the oracle owner to unregister an event

        @param _event Event address to unregister
    */
    function unRegisterEvent(address _event) public validAddress(_event) ownerOnly {
        delete events[_event];

        EventUnregistered(_event);
    }

    function isEventRegistered(address _event) private view returns (bool) {
        return (events[_event]);
    }

    /*
        @dev Allow the oracle owner to set a specific outcome for an event
        The event should be registered before calling set outcome.
        Note that setting the outcome does not directly affect the event contract. The event contract still needs to call the resolve()
        method in order to pull the outcome id from the oracle.

        @param _event       Event address to set outcome for
        @param _outcomeId   Winning outcome id
    */
    function setOutcome (address _event, uint _outcomeId) 
            public 
            validAddress(_event)
            greaterThanZero(_outcomeId)
            ownerOnly {
        
        require(isEventRegistered(_event));
        
        eventOutcome[_event] = _outcomeId;
        
        OutcomeAssigned(_event, _outcomeId);
    }

    /*
        @dev Returns the outcome id for a specific event

        @param _event   Event address

        @return         Outcome id
    */ 
    function getOutcome(address _event) public view returns (uint) {
        return eventOutcome[_event];
    }

    /*
        @dev Allow the oracle owner to set the oracle name

        @param _newName New oracle name
    */
    function setName(string _newName) external ownerOnly {
        name = _newName;
        OracleNameChanged(_newName);
    }
}
