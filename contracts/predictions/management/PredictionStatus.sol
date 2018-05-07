pragma solidity ^0.4.23;
import "./PredictionMetaData.sol";

/*
    @title PredictionStatus contract - holds prediction status and transitions.
*/
contract PredictionStatus is PredictionMetaData {

    /*
     *  Events
     */
    event PredictionPublished();
    event PredictionPaused();
    event PredictionCanceled();
    event PredictionResolved(address indexed _oracle, bytes32 indexed _winningOutcome);
   
    /**
        @dev Check the curren contract status

        @param _status Status to check
    */
    modifier statusIs(Status _status) {
        require(status == _status);
        _;
    }

    /*
        @dev constructor

        @param _owner       Prediction owner / operator
    */
    constructor()
        public
        {
            status = Status.Initializing;
    }

    /*
        @dev Allow the prediction owner to publish the prediction
    */
    function publish() public ownerOnly {
        require ((status == Status.Initializing) || 
                (status == Status.Paused));

        status = Status.Published;

        emit PredictionPublished();
    }

    /*
        @dev Allow the prediction owner to resolve the prediction.
    */
    function resolve(address _oracle, bytes32 _winningOutcome) statusIs(Status.Published) public {
        require (tokensPlacementEndTimeSeconds < now);

        status = Status.Resolved;

        emit PredictionResolved(_oracle, _winningOutcome);
    }

    /*
        @dev Allow the prediction owner to cancel the prediction.
    */
    function cancel() public ownerOnly {
        require ((status == Status.Published) ||
            (status == Status.Paused));
        
        status = Status.Canceled;

        emit PredictionCanceled();
    }

    /*
        @dev Allow the prediction owner to pause the prediction.
    */
    function pause() statusIs(Status.Published) public {
        status = Status.Paused;

        emit PredictionPaused();
    }

}
