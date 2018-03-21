pragma solidity ^0.4.18;
import "./PredictionStatus.sol";

contract PredictionMetaData is PredictionStatus {

    /*
     *  Members
     */
    string      public version = "0.1";
    string      public name;
    address     public oracleAddress;       // When the prediction is resolved the oracle will tell the prediction who is the winning outcome
    uint        public tokenPool;           // Total tokens used to buy units in this prediction

    /*
     *  Events
     */
    event PredictionNameChanged(string _newName);
    event OracleChanged(address _oracle);

    /*
        @dev Allow the prediction owner to change the name

        @param _newName Prediction name
    */
    function setPredictionName(string _newName) notEmpty(_newName) external ownerOnly {
        name = _newName;

        PredictionNameChanged(_newName);
    }

    /*
        @dev Allow the prediction owner to change the oracle address

        @param _oracle Oracle address
    */
    function setOracle(address _oracle) validAddress(_oracle) notThis(_oracle) external ownerOnly {
        require (status != Status.Resolved);

        oracleAddress = _oracle;

        OracleChanged(oracleAddress);
    }
}