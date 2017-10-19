pragma solidity ^0.4.0;


/*
    Provides support and utilities for contract ownership
*/
contract Ownable {
    address public owner;
    address public newOwner;

    event OwnerUpdate(address prevOwner, address newOwner);

    /**
        @dev constructor
    */
    function Ownable(address _owner) public {
        owner = _owner;
    }

    // allows execution by the owner only
    modifier ownerOnly {
        require(msg.sender == owner);
        _;
    }

    /**
        @dev allows transferring the contract ownership
        the new owner still needs to accept the transfer
        can only be called by the contract owner

        @param _newOwner    new contract owner
    */
    function transferOwnership(address _newOwner) public ownerOnly {
        require(_newOwner != owner);
        newOwner = _newOwner;
    }

    /**
        @dev used by a new owner to accept an ownership transfer
    */
    function acceptOwnership() public {
        require(msg.sender == newOwner);
        OwnerUpdate(owner, newOwner);
        owner = newOwner;
        newOwner = 0x0;
    }
}
