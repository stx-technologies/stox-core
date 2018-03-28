pragma solidity ^0.4.18;
import "./IUpgradableOracleFactoryImpl.sol";
import "../../Ownable.sol";

/*
    @title OracleFactory contract - A factory contract for generating oracles.
    It holds a factory interface object so we can update the oracle code without deploying a new oracle factory to the ethereum network.
 */
contract UpgradableOracleFactory is Ownable {
    
    /*
     * Members
     */
    address oracleFactoryImplRelay;
    
    function UpgradableOracleFactory(address _oracleFactoryImplRelay) 
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

