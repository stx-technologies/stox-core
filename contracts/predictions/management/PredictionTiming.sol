pragma solidity ^0.4.18;
import "./PredictionMetaData.sol";

contract PredictionTiming is PredictionMetaData {

    // Note: operator should close the units sale in his website some time before the actual unitBuyingEndTimeSeconds as the ethereum network
    // may take several minutes to process transactions
    uint        public unitBuyingEndTimeSeconds;   // After this time passes, users can no longer buy units
    uint        public predictionEndTimeSeconds;   // After this time passes, users can withdraw their winning units
    
    /*
     *  Events
     */
    event UnitBuyingEndTimeChanged(uint _newTime);
    event PredictionEndTimeChanged(uint _newTime);

    /*
        @dev constructor

        @param _owner                           Prediction owner / operator
        @param _predictionEndTimeSeconds        Prediction end time
        @param _unitBuyingEndTimeSeconds        Unit buying end time
    */
    function PredictionTiming (uint _predictionEndTimeSeconds, uint _unitBuyingEndTimeSeconds)
        public
        //Ownable(_owner)
        {
            require (_predictionEndTimeSeconds >= _unitBuyingEndTimeSeconds);

            unitBuyingEndTimeSeconds = _unitBuyingEndTimeSeconds;
            predictionEndTimeSeconds = _predictionEndTimeSeconds;
        }

    /*
        @dev Allow the prediction owner to change unit buying end time 

        @param _newUnitBuyingEndTimeSeconds Unit buying end time
    */
    function setUnitBuyingEndTime(uint _newUnitBuyingEndTimeSeconds) external  greaterThanZero(_newUnitBuyingEndTimeSeconds) ownerOnly {
         require ((predictionEndTimeSeconds >= _newUnitBuyingEndTimeSeconds) && 
                    ((status == Status.Initializing) || (status == Status.Paused))); 

         unitBuyingEndTimeSeconds = _newUnitBuyingEndTimeSeconds;
         UnitBuyingEndTimeChanged(_newUnitBuyingEndTimeSeconds);
    }

    /*
        @dev Allow the prediction owner to change the prediction end time 

        @param _newPredictionEndTimeSeconds Prediction end time
    */
    function setPredictionEndTime(uint _newPredictionEndTimeSeconds) external ownerOnly {
         require ((_newPredictionEndTimeSeconds >= unitBuyingEndTimeSeconds) && 
                    ((status == Status.Initializing) || (status == Status.Paused))); 

         predictionEndTimeSeconds = _newPredictionEndTimeSeconds;

         PredictionEndTimeChanged(_newPredictionEndTimeSeconds);
    }
   
}
