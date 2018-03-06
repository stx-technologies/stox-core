pragma solidity ^0.4.18;
import "../Ownable.sol";
import "../Utils.sol";
import "../oracles/Oracle.sol";
import "../token/IERC20Token.sol";

contract PredictionStatus is Ownable, Utils {

    /*
     *  Events
     */
    event PredictionPublished();
    event PredictionPaused();
    event PredictionCanceled();
    event PredictionResolved(address indexed _oracle, uint indexed _winningOutcomeId);
   
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
        Published,          // The prediction is published and users can now buy units.
        Resolved,           // The prediction is resolved and users can withdraw their units.
        Paused,             // The prediction is paused and users can no longer buy units until the prediction is published again.
        Canceled            // The prediction is canceled. Users can get their invested tokens refunded to them.
    }

    /*
     *  Members
     */
    Status      public status;

    /*
        @dev constructor

        @param _owner       Prediction owner / operator
    */
    function PredictionStatus (address _owner)
        public
        Ownable(_owner)
        {
            status = Status.Initializing;
        }

    /*
        @dev Allow the prediction owner to publish the prediction
    */
    function publish() {
        require ((status == Status.Initializing) || 
                (status == Status.Paused));

        status = Status.Published;

        PredictionPublished();
    }

    /*
        @dev Allow the prediction owner to resolve the prediction.
    */
    function resolve(address _oracle, uint _winningOutcomeId) statusIs(Status.Published) {
        
        status = Status.Resolved;

        PredictionResolved(_oracle, _winningOutcomeId);
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
    function pause() statusIs(Status.Published) {
        status = Status.Paused;

        PredictionPaused();
    }

}