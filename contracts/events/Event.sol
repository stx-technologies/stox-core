pragma solidity ^0.4.0;
import "../Ownable.sol";
import "../oracles/Oracle.sol";
import "../token/IERC20Token.sol";

contract Event is Ownable {

    event onEventPublished();
    event OnEventResolved(address indexed _oracle, address indexed _eventAddr, uint indexed _winningOutcomeId);
    event OnOptionBought(address indexed _owner, uint indexed _outcomeId, uint indexed _optionId, uint _tokenAmount);
    event OnEarningsWithdrawn(address indexed _owner, uint _tokenAmount);
    event OnEventCanceled();
    event OnUserOptionsCanceled(address indexed _owner);
    event OnUserOptionCanceled(address indexed _owner, uint _optionId);
    event OnOptionBuyingEndTimeChanged(uint _newTime);
    event OnEventEndTimeChanged(uint _newTime);
    event OnNameChanged(string _newName);
    event OnOutcomeAdded(uint indexed _outcomeId, string _name);

    struct Outcome {
        uint    id;
        string  name;
        uint    tokens;
    }

    struct Option {
        uint outcomeId;
        uint tokens;
        bool isWithdrawn;
    }

    string      public  version = "0.1";
    string      public  name;
    IERC20Token public  stox;
    bool        public  isPublished;
    uint        public  optionBuyingEndTimeSeconds;
    uint        public  eventEndTimeSeconds;
    uint        public  tokenPool;
    address     public  oracleAddress;
    uint        public  winningOutcomeId;
    Outcome[]   public  outcomes;
    Option[]    public  options;

    mapping(address => uint[]) public ownerOptions; // Mapping to see the total options for each user (user address -> option ids)

    // TODO: Add market maker
    function Event(address _owner, 
            address _oracle, 
            uint _eventEndTimeSeconds, 
            uint _optionBuyingEndTimeSeconds, 
            string _name, 
            IERC20Token _stox) 
            public 
            Ownable(_owner) {
        require ((_eventEndTimeSeconds >= _optionBuyingEndTimeSeconds) && (address(_oracle) != 0x0));
        oracleAddress = _oracle;
        eventEndTimeSeconds = _eventEndTimeSeconds;
        optionBuyingEndTimeSeconds = _optionBuyingEndTimeSeconds;
        name = _name;
        stox = _stox;
    }

    // Returns outcome id
    function addOutcome(string _name) public ownerOnly {
        require((isPublished == false));

        uint outcomeId = outcomes.length + 1;
        outcomes.push(Outcome(outcomeId, _name, 0));

        OnOutcomeAdded(outcomeId, _name);
    }

    function publish() public ownerOnly {
        require (outcomes.length > 1);
        isPublished = true;

        onEventPublished();
    }

    function setOptionBuyingEndTime(uint _newOptionBuyingEndTimeSeconds) external ownerOnly {
         require (eventEndTimeSeconds >= _newOptionBuyingEndTimeSeconds);

         optionBuyingEndTimeSeconds = _newOptionBuyingEndTimeSeconds;
         OnOptionBuyingEndTimeChanged(_newOptionBuyingEndTimeSeconds);
    }

    function setEventEndTime(uint _newEventEndTimeSeconds) external ownerOnly {
         require (_newEventEndTimeSeconds >= optionBuyingEndTimeSeconds);

         eventEndTimeSeconds = _newEventEndTimeSeconds;
         OnEventEndTimeChanged(_newEventEndTimeSeconds);
    }

    function setEventName(string _newName) external ownerOnly {
        name = _newName;
        OnNameChanged(_newName);
    }

    // TODO: Add provider address and max tokens
    // Note: operator should close the options sale several minutes before the actual optionBuyingEndTimeSeconds as blockchain may take 
    // several minutes to process transactions
    function buyOption(address _owner, uint _tokenAmount, uint _outcomeId) public {
        require((_owner != 0) &&
            (_tokenAmount > 0) &&
            (isPublished == true) &&
            isOutcomeExist(_outcomeId) &&
            (optionBuyingEndTimeSeconds > now));

        tokenPool = (tokenPool + _tokenAmount);
        uint optionId = options.push(Option(_outcomeId, _tokenAmount, false)) - 1;
        ownerOptions[_owner].push(optionId);
        outcomes[_outcomeId - 1].tokens = (outcomes[_outcomeId - 1].tokens + _tokenAmount);
        stox.transferFrom(_owner, this, _tokenAmount);

        // TODO: Make deposited user STX in event

        OnOptionBought(_owner, _outcomeId, optionId, _tokenAmount);
    }

    function buyOption(uint _tokenAmount, uint _outcomeId) external {
        buyOption(msg.sender, _tokenAmount, _outcomeId);
    }

    function resolve() public ownerOnly {
        require(isOutcomeExist((Oracle(oracleAddress)).getOutcome(this)));
        winningOutcomeId = (Oracle(oracleAddress)).getOutcome(this);

        OnEventResolved(oracleAddress, this, winningOutcomeId);
    }

    function withdrawEarnings() public {
        require (isOutcomeExist(winningOutcomeId) && (eventEndTimeSeconds < now) && (ownerOptions[msg.sender].length > 0));

        uint winningOutcomeTokens = outcomes[winningOutcomeId - 1].tokens;
        uint userWinTokens = 0;

        for (uint i = 0; i < ownerOptions[msg.sender].length; i++) {
            Option storage option = options[ownerOptions[msg.sender][i]];
            if ((option.isWithdrawn == false) && (option.outcomeId == winningOutcomeId) && (option.tokens > 0)) {
                // TODO: Use math library
                userWinTokens = userWinTokens + (option.tokens * tokenPool / winningOutcomeTokens);
                option.isWithdrawn = true;
            }
        }

        stox.transfer(msg.sender, userWinTokens);

        // TODO: Send userWinTokens STX to actual address
        OnEarningsWithdrawn(msg.sender, userWinTokens);
    }

    function calculateEarnings(address _owner) public constant returns (uint) {
        require (isOutcomeExist(winningOutcomeId));

        uint winningOutcomeTokens = outcomes[winningOutcomeId - 1].tokens;
        uint userWinTokens = 0;

        for (uint i = 0; i < ownerOptions[_owner].length; i++) {
            Option storage option = options[ownerOptions[_owner][i]];
            if ((option.outcomeId == winningOutcomeId) && (option.tokens > 0)) {
                // TODO: Use math library
                userWinTokens = userWinTokens + (option.tokens * tokenPool / winningOutcomeTokens);
            }
        }

        return (userWinTokens);
    }

    function isOutcomeExist(uint _outcomeId) constant private returns (bool) {
        return ((_outcomeId > 0) && (_outcomeId <= outcomes.length));
    }

    /// TODO: Implement
    function cancel() public ownerOnly {
        OnEventCanceled();
    }

    /// TODO: Implement
    function cancelOptions(address _owner) public ownerOnly {
        OnUserOptionsCanceled(_owner);
    }

    /// TODO: Implement
    function cancelOption(address _owner, uint _optionId) public ownerOnly {
        OnUserOptionCanceled(_owner, _optionId);
    }

    function getOutcome(uint _outcomeId) public constant returns (string) {
        require(isOutcomeExist(_outcomeId));

        return (outcomes[_outcomeId - 1].name);
    }

    // returns Outcome id for option id 0 and number of tokens (Use in case provider only allows one option per user)
    function getOwnerOption(address _owner) public returns (uint, uint) {
        return (options[ownerOptions[_owner][0]].outcomeId, options[ownerOptions[_owner][0]].tokens);
    }

    function getNumberOfOwnerOption(address _owner) public returns (uint) {
        return (ownerOptions[_owner].length);
    }

    // returns outcome id and number of tokens
    function getOwnerOption(address _owner, uint _index) public returns (uint, uint) {
        return (options[ownerOptions[_owner][_index]].outcomeId, options[ownerOptions[_owner][_index]].tokens);
    }
}
