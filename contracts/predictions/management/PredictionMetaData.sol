pragma solidity ^0.4.23;
import "./PredictionStatus.sol";

/*
    @title PredictionMetaData contract - holds generic data for a prediction.
*/
contract PredictionMetaData is PredictionStatus {

    /*
     *  Members
     */
    string      public version = "0.1";
    string      public name;
    address     public oracleAddress;       // When the prediction is resolved the oracle will tell the prediction who is the winning outcome
    
    /*
     *  Events
     */
    event PredictionNameChanged(string _newName);
    event OracleChanged(address _oracle);

    /*
     *  Constructor 
    */
    constructor(string _name, address _oracleAddress) 
        validAddress(_oracleAddress)
        notEmptyString(_name)
        public 
        {
            name = _name;
            oracleAddress = _oracleAddress;
    }


    /*
        @dev Allow the prediction owner to change the name

        @param _newName Prediction name
    */
    function setPredictionName(string _newName) notEmptyString(_newName) external ownerOnly {
        name = _newName;

        emit PredictionNameChanged(_newName);
    }

    /*
        @dev Allow the prediction owner to change the oracle address

        @param _oracle Oracle address
    */
    function setOracle(address _oracle) validAddress(_oracle) notThis(_oracle) external ownerOnly {
        require (status != Status.Resolved);

        oracleAddress = _oracle;

        emit OracleChanged(oracleAddress);
    }
}
