pragma solidity ^0.4.18;
import "../Ownable.sol";
import "../Utils.sol";
import "../oracles/Oracle.sol";
import "../token/IERC20Token.sol";
/**
    @title Pool event contract - Pool events distributes tokens between all winners according to 
    their proportional investment in the winning outcome. The event winning outcome is decided by the oracle.

    An example of a pool event
    ---------------------------
    An event has 3 different outcomes:
    1. Outcome1
    2. Outcome2
    3. Outcome3

    User A placed 100 tokens on Outcome1
    User B placed 300 tokens on Outcome1
    User C placed 100 tokens on Outcome2
    User D placed 100 tokens on Outcome3

    Total token pool: 600

    After the event ended, the oracle decided that the winning outcome is Outcome1

    Users options are now has the following value:
    User A -> 150 tokens (100 / (100 + 300) * 600)
    User B -> 450 tokens (300 / (100 + 300) * 600)
    Uset C -> 0 tokens
    Uset D -> 0 tokens

    @author Danny Hellman - <danny@stox.com>
 */
contract PoolEvent is Ownable, Utils {

    /*
     *  Events
     */
    event EventPublished();
    event EventPaused();
    event EventCanceled();
    event EventResolved(address indexed _oracle, uint indexed _winningOutcomeId);
    event OptionBought(address indexed _owner, uint indexed _outcomeId, uint indexed _optionId, uint _tokenAmount);
    event OptionsWithdrawn(address indexed _owner, uint _tokenAmount);
    event AllOptionsPaid();
    event UserRefunded(address indexed _owner, uint _tokenAmount);
    event AllUsersRefunded();
    event OptionBuyingEndTimeChanged(uint _newTime);
    event EventEndTimeChanged(uint _newTime);
    event EventNameChanged(string _newName);
    event OracleChanged(address _oracle);
    event OutcomeAdded(uint indexed _outcomeId, string _name);

    /**
        @dev Check the currect contract status

        @param _status Status to check
    */
    modifier statusIs(Status _status) {
        require(status == _status);
        _;
    }

    /**
        @dev Check if the event has this outcome id

        @param _outcomeId Outcome to check
    */
    modifier outcomeValid(uint _outcomeId) {
        require(isOutcomeExist(_outcomeId));
        _;
    }

    /*
     *  Enums and Structs
     */
    enum Status {
        Initializing,       // The status when the event is first created. During this stage we define the event outcomes.
        Published,          // The event is published and users can now buy options.
        Resolved,           // The event is resolved and users can redeem their options.
        Paused,             // The event is paused and users can no longer buy options until the event is published again.
        Canceled            // The event is canceled. Users can get their invested tokens refunded to them.
    }

    struct Outcome {
        uint    id;         // Id will start at 1, and increase by 1 for every new outcome
        string  name;           
        uint    tokens;     // Total tokens used to buy options for this outcome
    }

    struct Option {
        uint id;            // Id will start at 1, and increase by 1 for every new option
        uint outcomeId;
        uint tokens;
        bool isWithdrawn;
        address owner;
    }

    /*
     *  Members
     */
    string      public version = "0.1";
    string      public name;
    IERC20Token public stox;                       // Stox ERC20 token
    Status      public status;

    // Note: operator should close the options sale in his website some time before the actual optionBuyingEndTimeSeconds as the ethereum network  
    // may take several minutes to process transactions
    uint        public optionBuyingEndTimeSeconds; // After this time passes, users can no longer buy options

    uint        public eventEndTimeSeconds;        // After this time passes and the event is resolved, users can withdraw their winning options
    uint        public tokenPool;                  // Total tokens used to buy options in this event
    address     public oracleAddress;              // When the event is resolved the oracle will tell the event who is the winning outcome
    uint        public winningOutcomeId;
    Outcome[]   public outcomes;
    Option[]    public options;

    // Mapping to see all the options bought for each user and outcome (user address -> outcome id -> option id[])
    mapping(address => mapping(uint => uint[])) public ownerOptions; 

    /**
        @dev constructor

        @param _owner                       Event owner / operator
        @param _oracle                      The oracle provides the winning outcome for the event
        @param _eventEndTimeSeconds         Event end time
        @param _optionBuyingEndTimeSeconds  Option buying end time
        @param _name                        Event name
        @param _stox                        Stox ERC20 token address
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

    /**
        @dev Allow the event owner to change add a new outcome to the event

        @param _name Outcome name
    */
    function addOutcome(string _name) public ownerOnly statusIs(Status.Initializing) {
        uint outcomeId = safeAdd(outcomes.length, 1);
        outcomes.push(Outcome(outcomeId, _name, 0));

        OutcomeAdded(outcomeId, _name);
    }

    /**
        @dev Allow the event owner to publish the event - Users can now buy option on the various outcomes.
    */
    function publish() public ownerOnly {
        require ((outcomes.length > 1) && 
            ((status == Status.Initializing) || 
                (status == Status.Paused)));

        status = Status.Published;

        EventPublished();
    }

    /**
        @dev Allow the event owner to change option buying end time when event is initializing or paused

        @param _newOptionBuyingEndTimeSeconds Option buying end time
    */
    function setOptionBuyingEndTime(uint _newOptionBuyingEndTimeSeconds) greaterThanZero(_newOptionBuyingEndTimeSeconds) external ownerOnly {
         require ((eventEndTimeSeconds >= _newOptionBuyingEndTimeSeconds) && 
            ((status == Status.Initializing) || 
                (status == Status.Paused)));

         optionBuyingEndTimeSeconds = _newOptionBuyingEndTimeSeconds;
         OptionBuyingEndTimeChanged(_newOptionBuyingEndTimeSeconds);
    }

    /**
        @dev Allow the event owner to change the event end time when event is initializing or paused

        @param _newEventEndTimeSeconds Event end time
    */
    function setEventEndTime(uint _newEventEndTimeSeconds) external ownerOnly {
         require ((_newEventEndTimeSeconds >= optionBuyingEndTimeSeconds) && 
            ((status == Status.Initializing) || 
                (status == Status.Paused)));

         eventEndTimeSeconds = _newEventEndTimeSeconds;

         EventEndTimeChanged(_newEventEndTimeSeconds);
    }

    /**
        @dev Allow the event owner to change the name

        @param _newName Event name
    */
    function setEventName(string _newName) external ownerOnly {
        name = _newName;

        EventNameChanged(_newName);
    }

    /**
        @dev Allow the event owner to change the oracle address

        @param _oracle Oracle address
    */
    function setOracle(address _oracle) validAddress(_oracle) notThis(_oracle) external ownerOnly {
        require (status != Status.Resolved);

        oracleAddress = _oracle;

        OracleChanged(oracleAddress);
    }

    /**
        @dev Allow any user to buy an option on a specific outcome. note that users can buy multiple options on a specific outcome.
        Before calling buyOption the user should first call the approve(thisEventAddress, tokenAmount) on the 
        stox token (or any other ERC20 token).

        @param _owner       The option owner
        @param _tokenAmount The amount of tokens invested in this option
        @param _outcomeId   The outcome the user predicts.
    */
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

        stox.transferFrom(_owner, this, _tokenAmount);

        OptionBought(_owner, _outcomeId, optionId, _tokenAmount);
    }

    /**
        @dev Allow any user to buy an option on a specific outcome. 
        Before calling buyOption the user should first call the approve(thisEventAddress, tokenAmount) on the 
        stox token (or any other ERC20 token).

        @param _tokenAmount The amount of tokens invested in this option
        @param _outcomeId   The outcome the user predicts.
    */
    function buyOption(uint _tokenAmount, uint _outcomeId) external  {
        buyOption(msg.sender, _tokenAmount, _outcomeId);
    }

    /**
        @dev Allow the event owner to resolve the event.
        Before calling resolve() the oracle owner should first set the event outcome by calling setOutcome(thisEventAddress, winningOutcomeId) 
        in the Oracle contract.
    */
    function resolve() public statusIs(Status.Published) ownerOnly {
        require(isOutcomeExist((Oracle(oracleAddress)).getOutcome(this)) &&
            (optionBuyingEndTimeSeconds < now));

        winningOutcomeId = (Oracle(oracleAddress)).getOutcome(this);
        status = Status.Resolved;

        EventResolved(oracleAddress, winningOutcomeId);
    }

    /**
        @dev After the event is resolved the user can withdraw tokens from his winning options
        Alternatively the event owner / operator can choose to pay all the users himself using the payAllOptions() function
    */
    function withdrawOptions() public statusIs(Status.Resolved) {
        require(
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

        OptionsWithdrawn(msg.sender, userWinTokens);
    }

    /**
        @dev After the event is resolved the event owner can pay tokens for all the winning options
        Alternatively the event owner / operator can choose that the users will need to withdraw the funds using the withdrawOptions() function
    */    
    function payAllOptions() public ownerOnly statusIs(Status.Resolved) {

        uint winningOutcomeTokens = outcomes[winningOutcomeId - 1].tokens;

        for (uint i = 0; i < options.length; i++) {
            Option storage option = options[i];
            if ((option.id != 0) && (option.outcomeId == winningOutcomeId) && !option.isWithdrawn) {
                option.isWithdrawn = true;
                uint userWinTokens = safeMul(option.tokens, tokenPool) / winningOutcomeTokens;
                stox.transfer(option.owner, userWinTokens);
            }
        }

        AllOptionsPaid();
    }

    /**
        @dev Returns the amount of tokens a user can withdraw from his option after the event is resolved

        @param _owner   Options owner

        @return         Token amount
    */ 
    function calculateUserOptionsWithdrawValue(address _owner) external statusIs(Status.Resolved) constant returns (uint) {
        uint winningOutcomeTokens = outcomes[winningOutcomeId - 1].tokens;
        uint userWinTokens = 0;

        for (uint i = 0; i < ownerOptions[_owner][winningOutcomeId].length; i++) {
            Option storage option = options[ownerOptions[_owner][winningOutcomeId][i] - 1];
            userWinTokens = safeAdd(userWinTokens, (safeMul(option.tokens, tokenPool) / winningOutcomeTokens));
        }

        return (userWinTokens);
    }

    /**
        @dev Returns the amount of tokens a user invested in an outcome options

        @param _owner       Options owner
        @param _outcomeId   Outcome id

        @return             Token amount
    */ 
    function calculateUserOptionsValue(address _owner, uint _outcomeId) external constant returns (uint) {
        uint userTokens = 0;

        for (uint i = 0; i < ownerOptions[_owner][_outcomeId].length; i++) {
            Option storage option = options[ownerOptions[_owner][_outcomeId][i] - 1];
            userTokens = safeAdd(userTokens, option.tokens);
        }

        return (userTokens);
    }

    /**
        @dev Allow the event owner to cancel the event.
        After the event is canceled users can no longer buy options, and are able to get a refund for their options tokens.
    */
    function cancel() public ownerOnly {
        require ((status == Status.Published) ||
            (status == Status.Paused));
        
        status = Status.Canceled;

        EventCanceled();
    }

    /**
        @dev Allow to event owner / operator to cancel the user's options and refund the tokens.

        @param _owner Options owner
    */
    function refundUser(address _owner) public ownerOnly {
        require (status != Status.Resolved);
        
        performRefund(_owner);
    }

    /**
        @dev Allow the user to cancel his options and refund the tokens he invested in options. 
        Can be called only after the event is canceled.
    */
    function getRefund() public statusIs(Status.Canceled) {
        performRefund(msg.sender);
    }

    /**
        @dev Refund a specific user's options tokens and cancel the user's options.

        @param _owner Options owner
    */
    function performRefund(address _owner) private {
        require(tokenPool > 0);
        
        uint refundAmount = 0;

        for (uint outcomeId = 1; outcomeId <= outcomes.length; outcomeId++) {
            for (uint optionPos = 0; optionPos < ownerOptions[_owner][outcomeId].length; optionPos++) {
                uint optionId = ownerOptions[_owner][outcomeId][optionPos];

                if (options[optionId - 1].tokens > 0) {
                    outcomes[outcomeId - 1].tokens = safeSub(outcomes[outcomeId - 1].tokens, options[optionId - 1].tokens);
                    refundAmount = safeAdd(refundAmount, options[optionId - 1].tokens);

                    // After the token amount to refund is calculated - delete the user's tokens
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
            stox.transfer(_owner, refundAmount); // Refund the user
        }

        UserRefunded(_owner, refundAmount);
    }

    /**
        @dev Allow to event owner / operator to cancel all the users options and refund their tokens.
    */
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

    /**
        @dev Allow the event owner to pause the event.
        After the event is paused users can no longer buy options until the event is republished
    */
    function pause() public statusIs(Status.Published) ownerOnly {
        status = Status.Paused;

        EventPaused();
    }

    /**
        @dev Returns the outcome name of a specific outcome id

        @param _outcomeId   Outcome id

        @return             Outcome name
    */
    function getOutcome(uint _outcomeId) public constant returns (string) {
        require(isOutcomeExist(_outcomeId));

        return (outcomes[_outcomeId - 1].name);
    }

    /**
        @dev Returns true if the event contains a specific outcome id

        @param _outcomeId   Outcome id

        @return             true if the outcome exists
    */
    function isOutcomeExist(uint _outcomeId) private constant returns (bool) {
        return ((_outcomeId > 0) && (_outcomeId <= outcomes.length));
    }

    /**
        @dev Returns true if the user's options on an outcome are all withdrawn

        @param _owner       Options owner
        @param _outcomeId   Outcome id

        @return             true if the user's options  on an outcome are all withdrawn
    */
    function areOptionsWithdrawn(address _owner, uint _outcomeId) private constant returns(bool) {

        for (uint i = 0; i < ownerOptions[_owner][_outcomeId].length; i++) {
            if (!options[ownerOptions[_owner][_outcomeId][i] - 1].isWithdrawn) {
                return false;
            }
        }

        return true;
    }

    /**
        @dev Returns true if the user bought options on a specific outcome

        @param _owner       Options owner
        @param _outcomeId   Outcome id

        @return             true if the user bought options on a specific outcome
    */
    function hasOptions(address _owner, uint _outcomeId) private constant returns(bool) {
        return (ownerOptions[_owner][_outcomeId].length > 0);
    }
}
