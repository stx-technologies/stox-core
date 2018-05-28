pragma solidity ^0.4.23;
import "./IUpgradableOracleFactoryImpl.sol";
import "../../Ownable.sol";

/*
    @title UpgradableOracleFactory contract - A factory contract for generating oracles.
    Holds a reference to the desired type of Oracle factory implementation.
    Eevry call to this that factory is delegated via this contract. 
 */
contract UpgradableOracleFactory is Ownable {
    
    /*
     * Members
     */
    address oracleFactoryImplRelay;
    
    constructor(address _oracleFactoryImplRelay) 
        public 
        Ownable(msg.sender) 
        {
            oracleFactoryImplRelay = _oracleFactoryImplRelay;
    }

    /*
        @dev Set a new OracleFactoryImpl address

        @param _oracleFactoryImplRelay       OracleFactoryImpl new address
    */
    function setOracleFactoryImplRelay(address _oracleFactoryImplRelay) 
        public 
        ownerOnly 
        {
            oracleFactoryImplRelay = _oracleFactoryImplRelay;
    }

    /*
        @dev Fallback function to delegate calls to the OracleFactoryImpl relay contract

    */
    function() public {
         
        if (!oracleFactoryImplRelay.delegatecall(msg.data)) 
           revert();
    }
  
}

