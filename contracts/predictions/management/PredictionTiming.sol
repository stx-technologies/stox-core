pragma solidity ^0.4.23;
import "./PredictionStatus.sol";

/*
    @title PredictionTiming contract - holds functions controling chnages in prediction timing.
*/
contract PredictionTiming is PredictionStatus {

    // Note: operator should close the tokens sale in his website some time before the actual tokensPlacementEndTimeSeconds as the ethereum network
    // may take several minutes to process transactions
    
    /*
     *  Events
     */
    event TokenPlacementEndTimeChanged(uint _newTime);
    event PredictionEndTimeChanged(uint _newTime);

    /*
        @dev constructor

        @param _owner                           Prediction owner / operator
        @param _predictionEndTimeSeconds        Prediction end time
        @param _tokensPlacementEndTimeSeconds   Tokens placement buying end time
    */
    constructor(uint _predictionEndTimeSeconds, uint _tokensPlacementEndTimeSeconds)
        greaterThanZero(_predictionEndTimeSeconds)
        greaterThanZero(_tokensPlacementEndTimeSeconds)
        public
        {
            require (_predictionEndTimeSeconds >= _tokensPlacementEndTimeSeconds);

            tokensPlacementEndTimeSeconds = _tokensPlacementEndTimeSeconds;
            predictionEndTimeSeconds = _predictionEndTimeSeconds;
        }

    /*
        @dev Allow the prediction owner to change unit buying end time 

        @param _newTokensPlacementEndTimeSeconds   Tokens placement buying end time
    */
    function setTokensPlacementBuyingEndTime(uint _newTokensPlacementEndTimeSeconds) external  greaterThanZero(_newTokensPlacementEndTimeSeconds) ownerOnly {
         require ((predictionEndTimeSeconds >= _newTokensPlacementEndTimeSeconds) && 
                    ((status == Status.Initializing) || (status == Status.Paused))); 

         tokensPlacementEndTimeSeconds = _newTokensPlacementEndTimeSeconds;
         emit TokenPlacementEndTimeChanged(_newTokensPlacementEndTimeSeconds);
    }

    /*
        @dev Allow the prediction owner to change the prediction end time 

        @param _newPredictionEndTimeSeconds Prediction end time
    */
    function setPredictionEndTime(uint _newPredictionEndTimeSeconds) external ownerOnly {
         require ((_newPredictionEndTimeSeconds >= tokensPlacementEndTimeSeconds) && 
                    ((status == Status.Initializing) || (status == Status.Paused))); 

         predictionEndTimeSeconds = _newPredictionEndTimeSeconds;

         emit PredictionEndTimeChanged(_newPredictionEndTimeSeconds);
    }
   
}
