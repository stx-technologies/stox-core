pragma solidity ^0.4.18;
import "../../Ownable.sol";
import "../../Utils.sol";
import "../../token/IERC20Token.sol";

/*
    @title PredictionStatus contract - holds prediction status and transitions.
*/
contract PredictionStatus is Ownable, Utils {

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
     *  Enums and Structs
     */
    enum Status {
        Initializing,       // The status when the prediction is first created. 
        Published,          // The prediction is published and users can now place tokens.
        Resolved,           // The prediction is resolved and users can withdraw their tokens.
        Paused,             // The prediction is paused and users can no longer place tokens until the prediction is published again.
        Canceled            // The prediction is canceled. Users can get their placed tokens refunded to them.
    }

    /*
     *  Members
     */
    Status      public status;

    /*
        @dev constructor

        @param _owner       Prediction owner / operator
    */
    function PredictionStatus ()
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

        PredictionPublished();
    }

    /*
        @dev Allow the prediction owner to resolve the prediction.
    */
    function resolve(address _oracle, bytes32 _winningOutcome) statusIs(Status.Published) public {
        
        status = Status.Resolved;

        PredictionResolved(_oracle, _winningOutcome);
    }

    /*
        @dev Allow the prediction owner to cancel the prediction.
    */
    function cancel() public ownerOnly {
        require ((status == Status.Published) ||
            (status == Status.Paused));
        
        status = Status.Canceled;

        PredictionCanceled();
    }

    /*
        @dev Allow the prediction owner to pause the prediction.
    */
    function pause() statusIs(Status.Published) public {
        status = Status.Paused;

        PredictionPaused();
    }

}
