pragma solidity ^0.4.23;
import "../../Ownable.sol";
import "../../Utils.sol";
import "../../token/IERC20Token.sol";
import "../prizeCalculations/IPrizeCalculation.sol";

/*
    @title PredictionMetaData contract - holds generic data for a prediction.
*/
contract PredictionMetaData is Ownable, Utils {

    /*
     *  Members
     */

     /*
     *  Enums and Structs
     */
    enum Status {
        Initializing,       // The status when the prediction is first created. 
        Published,          // The prediction is published and users can now place tokens.
        Resolved,           // The prediction is resolved and users can withdraw their tokens.
        Paused,             // The prediction is paused and users can no longer place tokens until the prediction is published again.
        Canceled            // The prediction is canceled. Users can get their placed tokens refunded to them.
    }

    
    Status              public status;
    string              public version = "0.1";
    string              public name;
    address             public oracleAddress;       // When the prediction is resolved the oracle will tell the prediction who is the winning outcome
    uint                public tokensPlacementEndTimeSeconds;   // After this time passes, users can no longer place tokens
    uint                public predictionEndTimeSeconds;   // After this time passes, users can withdraw their winning tokens placements
    IPrizeCalculation   public prizeCalculation;  //
    
    /*
     *  Events
     */
    event PredictionNameChanged(string _newName);
    event OracleChanged(address _oracle);

    /*
     *  Constructor 
    */
    constructor(string _name, address _oracleAddress, IPrizeCalculation _prizeCalculation) 
        validAddress(_oracleAddress)
        validAddress(_prizeCalculation)
        notEmptyString(_name)
        public 
        {
            name = _name;
            oracleAddress = _oracleAddress;
            prizeCalculation = _prizeCalculation;
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
