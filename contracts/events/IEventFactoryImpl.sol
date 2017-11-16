pragma solidity ^0.4.18;

/*
    @title IEventFactoryImpl contract - A interface contract for the events factory.
 */
contract IEventFactoryImpl {
    function createPoolEvent(address _owner, address _oracle, uint _eventEndTimeSeconds, uint _optionBuyingEndTimeSeconds, string _name) public returns(address); 
}
