pragma solidity ^0.4.18;
import "../Ownable.sol";
import "../Utils.sol";
import "../oracles/Oracle.sol";
import "../token/IERC20Token.sol";

/// @title Pool event contract - Pool events distributes tokens between all winners according to 
/// their proportional investment in the winning outcome. The event winning outcome is decided by the oracle.
/// @author Danny Hellman - <danny@stox.com>
contract PoolEvent is Ownable, Utils {

    /*
     *  Events
     */
    event EventPublished();
    event EventPaused();
    event EventCanceled();
    event EventResolved(address indexed _oracle, uint indexed _winningOutcomeId);
    event OptionBought(address indexed _owner, uint indexed _outcomeId, uint indexed _optionId, uint _tokenAmount);
    event OptionsRedeemed(address indexed _owner, uint _tokenAmount);
    event AllOptionsRedeemed();
    event UserRefunded(address indexed _owner, uint _tokenAmount);
    event AllUsersRefunded();
    event OptionBuyingEndTimeChanged(uint _newTime);
    event EventEndTimeChanged(uint _newTime);
    event EventNameChanged(string _newName);
    event OracleChanged(address _oracle);
    event OutcomeAdded(uint indexed _outcomeId, string _name);

    modifier statusIs(Status _status) {
        require(status == _status);
        _;
    }

    modifier outcomeValid(uint _outcome) {
        require(isOutcomeExist(_outcome));
        _;
    }

    enum Status {
        Initializing,   // Status when the event is created. This is when we define the event outcomes.
        Published,      // The event is published and users can now buy options.
        Resolved,       // The event is resolved and users can redeem their options.
        Paused,         // The event is paused and users can no longer buy options until the event is published again.
        Canceled        // The event is canceled. Users can get their invested tokens refunded to them.
    }

    struct Outcome {
        uint    id;
        string  name;
        uint    tokens; // Total tokens used to buy options for this outcome
    }

    struct Option {
        uint id;
        uint outcomeId;
        uint tokens;
        bool isWithdrawn;
        address owner;
    }

    string      public  version = "0.1";
    string      public  name;
    IERC20Token public  stox;
    Status      public  status;
    uint        public  optionBuyingEndTimeSeconds;
    uint        public  eventEndTimeSeconds;
    uint        public  tokenPool;                  // Total tokens used to buy options in this event
    address     public  oracleAddress;              // When the event is resolved the oracle will tell the event who is the winning outcome
    uint        public  winningOutcomeId;
    Outcome[]   public  outcomes;
    Option[]    public  options;

    // Mapping to see the total options for each user and outcome (user address -> outcome id -> option id[])
    mapping(address => mapping(uint => uint[])) public ownerOptions; 

    /**
        @dev constructor
    */
    function PoolEvent(address _owner,
            address _oracle,
            uint _eventEndTimeSeconds,
            uint _optionBuyingEndTimeSeconds,
            string _name,
            IERC20Token _stox)
            public 
            validAddress(_oracle)
            validAddress(_owner)
            greaterThanZero(_eventEndTimeSeconds)
            greaterThanZero(_optionBuyingEndTimeSeconds)
            Ownable(_owner) {

        require (_eventEndTimeSeconds >= _optionBuyingEndTimeSeconds);

        status = Status.Initializing;
        oracleAddress = _oracle;
        eventEndTimeSeconds = _eventEndTimeSeconds;
        optionBuyingEndTimeSeconds = _optionBuyingEndTimeSeconds;
        name = _name;
        stox = _stox;
    }

    // Returns outcome id
    function addOutcome(string _name) public ownerOnly statusIs(Status.Initializing) {
        uint outcomeId = safeAdd(outcomes.length, 1);
        outcomes.push(Outcome(outcomeId, _name, 0));

        OutcomeAdded(outcomeId, _name);
    }

    function publish() public ownerOnly {
        require ((outcomes.length > 1) && 
            ((status == Status.Initializing) || 
                (status == Status.Paused)));

        status = Status.Published;

        EventPublished();
    }

    // Change option buying end time when event is initializing, paused or canceled
    function setOptionBuyingEndTime(uint _newOptionBuyingEndTimeSeconds) greaterThanZero(_newOptionBuyingEndTimeSeconds) external ownerOnly {
         require ((eventEndTimeSeconds >= _newOptionBuyingEndTimeSeconds) && 
            ((status == Status.Initializing) || 
                (status == Status.Paused)));

         optionBuyingEndTimeSeconds = _newOptionBuyingEndTimeSeconds;
         OptionBuyingEndTimeChanged(_newOptionBuyingEndTimeSeconds);
    }

    function setEventEndTime(uint _newEventEndTimeSeconds) external ownerOnly {
         require ((_newEventEndTimeSeconds >= optionBuyingEndTimeSeconds) && 
            ((status == Status.Initializing) || 
                (status == Status.Paused)));

         eventEndTimeSeconds = _newEventEndTimeSeconds;

         EventEndTimeChanged(_newEventEndTimeSeconds);
    }

    function setEventName(string _newName) external ownerOnly {
        name = _newName;

        EventNameChanged(_newName);
    }

    function setOracle(address _oracle) validAddress(_oracle) notThis(_oracle) external ownerOnly {
        require (status != Status.Resolved);

        oracleAddress = _oracle;

        OracleChanged(oracleAddress);
    }

    // TODO: Add provider address and max tokens
    // TODO: Allow user to increase his bet
    // Note: operator should close the options sale several minutes before the actual optionBuyingEndTimeSeconds as blockchain may take 
    // several minutes to process transactions
    function buyOption(address _owner, uint _tokenAmount, uint _outcomeId) 
            public
            statusIs(Status.Published)
            validAddress(_owner)
            greaterThanZero(_tokenAmount)
            outcomeValid(_outcomeId) {
        
        require(
            (stox.allowance(_owner, this) >= _tokenAmount) &&
            (optionBuyingEndTimeSeconds > now));

        tokenPool = safeAdd(tokenPool, _tokenAmount);
        outcomes[_outcomeId - 1].tokens = safeAdd(outcomes[_outcomeId - 1].tokens, _tokenAmount);

        uint optionId = safeAdd(options.length, 1);
        options.push(Option(optionId, _outcomeId, _tokenAmount, false, _owner));
        ownerOptions[_owner][_outcomeId].push(optionId);

        // User should call "approve" first on the smart token contract
        stox.transferFrom(_owner, this, _tokenAmount);

        OptionBought(_owner, _outcomeId, optionId, _tokenAmount);
    }

    function buyOption(uint _tokenAmount, uint _outcomeId) external  {
        buyOption(msg.sender, _tokenAmount, _outcomeId);
    }

    function resolve() public statusIs(Status.Published) ownerOnly {
        require(isOutcomeExist((Oracle(oracleAddress)).getOutcome(this)));

        winningOutcomeId = (Oracle(oracleAddress)).getOutcome(this);
        status = Status.Resolved;

        EventResolved(oracleAddress, winningOutcomeId);
    }

    function redeemUserOptions() public statusIs(Status.Resolved) {
        require(
            (eventEndTimeSeconds < now) &&
            (hasOptions(msg.sender, winningOutcomeId) &&
            (!areOptionsWithdrawn(msg.sender, winningOutcomeId))));

        uint winningOutcomeTokens = outcomes[winningOutcomeId - 1].tokens;
        uint userWinTokens = 0;

        for (uint i = 0; i < ownerOptions[msg.sender][winningOutcomeId].length; i++) {
            Option storage option = options[ownerOptions[msg.sender][winningOutcomeId][i] - 1];
            userWinTokens = safeAdd(userWinTokens, (safeMul(option.tokens, tokenPool) / winningOutcomeTokens));
            option.isWithdrawn = true;
        }

        if (userWinTokens > 0) {
            stox.transfer(msg.sender, userWinTokens);
        }

        OptionsRedeemed(msg.sender, userWinTokens);
    }

    function redeemAllOptions() public ownerOnly statusIs(Status.Resolved) {
        require(eventEndTimeSeconds < now);

        uint winningOutcomeTokens = outcomes[winningOutcomeId - 1].tokens;

        for (uint i = 0; i < options.length; i++) {
            Option storage option = options[i];
            if ((option.id != 0) && (option.outcomeId == winningOutcomeId) && !option.isWithdrawn) {
                option.isWithdrawn = true;
                uint userWinTokens = safeMul(option.tokens, tokenPool) / winningOutcomeTokens;
                stox.transfer(option.owner, userWinTokens);
            }
        }

        AllOptionsRedeemed();
    }

    function calculateUserOptionsRedeemValue(address _owner) external statusIs(Status.Resolved) constant returns (uint) {
        uint winningOutcomeTokens = outcomes[winningOutcomeId - 1].tokens;
        uint userWinTokens = 0;

        for (uint i = 0; i < ownerOptions[_owner][winningOutcomeId].length; i++) {
            Option storage option = options[ownerOptions[_owner][winningOutcomeId][i] - 1];
            userWinTokens = safeAdd(userWinTokens, (safeMul(option.tokens, tokenPool) / winningOutcomeTokens));
        }

        return (userWinTokens);
    }

    function calculateUserOptionsValue(address _owner, _outcomeId) external constant returns (uint) {
        uint userTokens = 0;

        for (uint i = 0; i < ownerOptions[_owner][_outcomeId].length; i++) {
            Option storage option = options[ownerOptions[_owner][_outcomeId][i] - 1];
            userTokens = safeAdd(userTokens, option.tokens);
        }

        return (userTokens);
    }

    /// TODO: Implement
    function cancel() public ownerOnly {
        require ((status == Status.Published) ||
            (status == Status.Paused));
        
        status = Status.Canceled;

        EventCanceled();
    }

    // Cancel the user options and refund the tokens. Called by the event operator.
    function refund(address _owner) public ownerOnly {
        require (status != Status.Resolved);
        
        performRefund(_owner);
    }

    // Cancel the user options and refund the tokens. Called by the user after the event is canceled. 
    function refund() public statusIs(Status.Canceled) {
        performRefund(msg.sender);
    }

    function performRefund(address _owner) private {
        require(tokenPool > 0);
        
        uint refundAmount = 0;

        for (uint outcomeId = 1; outcomeId <= outcomes.length; outcomeId++) {
            for (uint optionPos = 0; optionPos < ownerOptions[_owner][outcomeId].length; optionPos++) {
                uint optionId = ownerOptions[_owner][outcomeId][optionPos];

                if (options[optionId - 1].tokens > 0) {
                    outcomes[outcomeId - 1].tokens = safeSub(outcomes[outcomeId - 1].tokens, options[optionId - 1].tokens);
                    refundAmount = safeAdd(refundAmount, options[optionId - 1].tokens);

                    delete ownerOptions[_owner][outcomeId][optionPos];
                    delete options[optionId - 1];
                }
            }

            if (ownerOptions[_owner][outcomeId].length > 0) {
                ownerOptions[_owner][outcomeId].length = 0;
            }
        }

        if (refundAmount > 0) {
            tokenPool = safeSub(tokenPool, refundAmount);
            stox.transfer(_owner, refundAmount);
        }

        UserRefunded(_owner, refundAmount);
    }

    function refundAllUsers() public ownerOnly statusIs(Status.Canceled) {
        require(tokenPool > 0);

        for (uint i = 0; i < options.length; i++) {
            Option storage option = options[i];
            if (option.id != 0) {
                uint refundTokens = option.tokens;
                address owner = option.owner;
                delete options[i];

                stox.transfer(owner, refundTokens);
            }
        }

        tokenPool = 0;
        
        AllUsersRefunded();
    }

    function pause() public statusIs(Status.Published) ownerOnly {
        status = Status.Paused;

        EventPaused();
    }

    function getOutcome(uint _outcomeId) public constant returns (string) {
        require(isOutcomeExist(_outcomeId));

        return (outcomes[_outcomeId - 1].name);
    }

    function isOutcomeExist(uint _outcomeId) private constant returns (bool) {
        return ((_outcomeId > 0) && (_outcomeId <= outcomes.length));
    }

    function areOptionsWithdrawn(address _owner, uint _outcomeId) private constant returns(bool) {

        for (uint i = 0; i < ownerOptions[_owner][_outcomeId].length; i++) {
            if (!options[ownerOptions[_owner][_outcomeId][i] - 1].isWithdrawn) {
                return false;
            }
        }

        return true;
    }

    function hasOptions(address _owner, uint _outcomeId) private constant returns(bool) {
        return (ownerOptions[_owner][_outcomeId].length > 0);
    }
}
