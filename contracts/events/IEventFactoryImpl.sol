pragma solidity ^0.4.0;

contract IEventFactoryImpl {
    function createEvent(address _owner, address _oracle, uint _eventEndTimeSeconds, uint _optionBuyingEndTimeSeconds, string _name) public returns(address); 
}