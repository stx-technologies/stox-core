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

    After the event ends, the oracle decides that the winning outcome is Outcome1

    Users can now withdraw from their items the following token amount:
    User A -> 150 tokens (100 / (100 + 300) * 600)
    User B -> 450 tokens (300 / (100 + 300) * 600)
    User C -> 0 tokens
    User D -> 0 tokens
 */
contract PoolEvent is Ownable, Utils {

    /*
    *   Constants
    */
    uint private constant MAX_ITEMS_WITHDRAWN   = 50;
    uint private constant MAX_ITEMS_PAID        = 100;
    uint private constant MAX_ITEMS_REFUND      = 50;


    /*
     *  Events
     */
    event EventPublished();
    event EventPaused();
    event EventCanceled();
    event EventResolved(address indexed _oracle, uint indexed _winningOutcomeId);
    event ItemBought(address indexed _owner, uint indexed _outcomeId, uint indexed _itemId, uint _tokenAmount);
    event ItemsWithdrawn(address indexed _owner, uint _tokenAmount);
    event ItemsPaid(uint _itemIdStart, uint _itemIdEnd);
    event UserRefunded(address indexed _owner, uint _outcomeId, uint _tokenAmount);
    event ItemsRefunded(uint _itemIdStart, uint _itemIdEnd);
    event ItemBuyingEndTimeChanged(uint _newTime);
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
        Published,          // The event is published and users can now buy items.
        Resolved,           // The event is resolved and users can withdraw their items.
        Paused,             // The event is paused and users can no longer buy items until the event is published again.
        Canceled            // The event is canceled. Users can get their invested tokens refunded to them.
    }

    struct Outcome {
        uint    id;         // Id will start at 1, and increase by 1 for every new outcome
        string  name;           
        uint    tokens;     // Total tokens used to buy items for this outcome
    }

    struct Item {
        uint    id;         // Id will start at 1, and increase by 1 for every new item
        uint    outcomeId;
        uint    tokens;
        bool    isWithdrawn;
        address owner;
    }

    /*
     *  Members
     */
    string      public version = "0.1";
    string      public name;
    IERC20Token public stox;                       // Stox ERC20 token
    Status      public status;

    // Note: operator should close the items sale in his website some time before the actual itemBuyingEndTimeSeconds as the ethereum network  
    // may take several minutes to process transactions
    uint        public itemBuyingEndTimeSeconds;   // After this time passes, users can no longer buy items

    uint        public eventEndTimeSeconds;        // After this time passes and the event is resolved, users can withdraw their winning items
    uint        public tokenPool;                  // Total tokens used to buy items in this event
    address     public oracleAddress;              // When the event is resolved the oracle will tell the event who is the winning outcome
    uint        public winningOutcomeId;
    Outcome[]   public outcomes;
    Item[]      public items;

    // Mapping to see all the items bought for each user and outcome (user address -> outcome id -> item id[])
    mapping(address => mapping(uint => uint[])) public ownerItems; 

    /*
        @dev constructor

        @param _owner                       Event owner / operator
        @param _oracle                      The oracle provides the winning outcome for the event
        @param _eventEndTimeSeconds         Event end time
        @param _itemBuyingEndTimeSeconds  Item buying end time
        @param _name                        Event name
        @param _stox                        Stox ERC20 token address
    */
    function PoolEvent(address _owner,
            address _oracle,
            uint _eventEndTimeSeconds,
            uint _itemBuyingEndTimeSeconds,
            string _name,
            IERC20Token _stox)
            public 
            validAddress(_oracle)
            validAddress(_owner)
            validAddress(_stox)
            greaterThanZero(_eventEndTimeSeconds)
            greaterThanZero(_itemBuyingEndTimeSeconds)
            notEmpty(_name)
            Ownable(_owner) {

        require (_eventEndTimeSeconds >= _itemBuyingEndTimeSeconds);

        status = Status.Initializing;
        oracleAddress = _oracle;
        eventEndTimeSeconds = _eventEndTimeSeconds;
        itemBuyingEndTimeSeconds = _itemBuyingEndTimeSeconds;
        name = _name;
        stox = _stox;
    }

    /*
        @dev Allow the event owner to change add a new outcome to the event

        @param _name Outcome name
    */
    function addOutcome(string _name) public ownerOnly notEmpty(_name) statusIs(Status.Initializing) {
        uint outcomeId = safeAdd(outcomes.length, 1);
        outcomes.push(Outcome(outcomeId, _name, 0));

        OutcomeAdded(outcomeId, _name);
    }

    /*
        @dev Allow the event owner to publish the event - Users can now buy item on the various outcomes.
    */
    function publish() public ownerOnly {
        require ((outcomes.length > 1) && 
            ((status == Status.Initializing) || 
                (status == Status.Paused)));

        status = Status.Published;

        EventPublished();
    }

    /*
        @dev Allow the event owner to change item buying end time when event is initializing or paused

        @param _newItemBuyingEndTimeSeconds Item buying end time
    */
    function setItemBuyingEndTime(uint _newItemBuyingEndTimeSeconds) greaterThanZero(_newItemBuyingEndTimeSeconds) external ownerOnly {
         require ((eventEndTimeSeconds >= _newItemBuyingEndTimeSeconds) && 
            ((status == Status.Initializing) || 
                (status == Status.Paused)));

         itemBuyingEndTimeSeconds = _newItemBuyingEndTimeSeconds;
         ItemBuyingEndTimeChanged(_newItemBuyingEndTimeSeconds);
    }

    /*
        @dev Allow the event owner to change the event end time when event is initializing or paused

        @param _newEventEndTimeSeconds Event end time
    */
    function setEventEndTime(uint _newEventEndTimeSeconds) external ownerOnly {
         require ((_newEventEndTimeSeconds >= itemBuyingEndTimeSeconds) && 
            ((status == Status.Initializing) || 
                (status == Status.Paused)));

         eventEndTimeSeconds = _newEventEndTimeSeconds;

         EventEndTimeChanged(_newEventEndTimeSeconds);
    }

    /*
        @dev Allow the event owner to change the name

        @param _newName Event name
    */
    function setEventName(string _newName) notEmpty(_newName) external ownerOnly {
        name = _newName;

        EventNameChanged(_newName);
    }

    /*
        @dev Allow the event owner to change the oracle address

        @param _oracle Oracle address
    */
    function setOracle(address _oracle) validAddress(_oracle) notThis(_oracle) external ownerOnly {
        require (status != Status.Resolved);

        oracleAddress = _oracle;

        OracleChanged(oracleAddress);
    }

    /*
        @dev Allow any user to buy an item on a specific outcome. note that users can buy multiple items on a specific outcome.
        Before calling buyItem the user should first call the approve(thisEventAddress, tokenAmount) on the 
        stox token (or any other ERC20 token).

        @param _owner       The item owner
        @param _tokenAmount The amount of tokens invested in this item
        @param _outcomeId   The outcome the user predicts.
    */
    function buyItem(address _owner, uint _tokenAmount, uint _outcomeId) 
            public
            statusIs(Status.Published)
            validAddress(_owner)
            greaterThanZero(_tokenAmount)
            outcomeValid(_outcomeId) {
        
        require(
            itemBuyingEndTimeSeconds > now);

        tokenPool = safeAdd(tokenPool, _tokenAmount);
        outcomes[_outcomeId - 1].tokens = safeAdd(outcomes[_outcomeId - 1].tokens, _tokenAmount);

        uint itemId = safeAdd(items.length, 1);
        items.push(Item(itemId, _outcomeId, _tokenAmount, false, _owner));
        ownerItems[_owner][_outcomeId].push(itemId);

        assert(stox.transferFrom(_owner, this, _tokenAmount));

        ItemBought(_owner, _outcomeId, itemId, _tokenAmount);
    }

    /*
        @dev Allow any user to buy an item on a specific outcome. 
        Before calling buyItem the user should first call the approve(thisEventAddress, tokenAmount) on the 
        stox token (or any other ERC20 token).

        @param _tokenAmount The amount of tokens invested in this item
        @param _outcomeId   The outcome the user predicts.
    */
    function buyItem(uint _tokenAmount, uint _outcomeId) external  {
        buyItem(msg.sender, _tokenAmount, _outcomeId);
    }

    /*
        @dev Allow the event owner to resolve the event.
        Before calling resolve() the oracle owner should first set the event outcome by calling setOutcome(thisEventAddress, winningOutcomeId) 
        in the Oracle contract.
    */
    function resolve() public statusIs(Status.Published) ownerOnly {
        require(isOutcomeExist((Oracle(oracleAddress)).getOutcome(this)) &&
            (itemBuyingEndTimeSeconds < now));

        winningOutcomeId = (Oracle(oracleAddress)).getOutcome(this);

        // In the very unlikely event that no one bought an item on the winning outcome - throw exception.
        // The only items for the event operator is to cancel the event and refund the money, or change the event end time)
        assert(outcomes[winningOutcomeId - 1].tokens > 0);

        status = Status.Resolved;

        EventResolved(oracleAddress, winningOutcomeId);
    }

    /*
        @dev After the event is resolved the user can withdraw tokens from his winning items
        Alternatively the event owner / operator can choose to pay all the users himself using the payAllItems() function
    */
    function withdrawItems() public statusIs(Status.Resolved) {
        withdrawItemsBulk(0, MAX_ITEMS_WITHDRAWN);
    }

    /*
        @dev After the event is resolved the user can withdraw tokens from his winning items
        Alternatively the event owner / operator can choose to pay all the users himself using the payAllItems() function

        @param _indexStart From which item index should we start withdrawing
        @param _maxItems   How many items should we withdraw
    */
    function withdrawItemsBulk(uint _indexStart, uint _maxItems) public statusIs(Status.Resolved) greaterThanZero(_maxItems) {
        require(
            (hasItems(msg.sender, winningOutcomeId) &&
            (!areItemsWithdrawn(msg.sender, winningOutcomeId, _indexStart, _maxItems))));

        uint winningOutcomeTokens = outcomes[winningOutcomeId - 1].tokens;
        uint userWinTokens = 0;

        uint indexEnd = safeAdd(_indexStart, _maxItems);
        if (indexEnd > ownerItems[msg.sender][winningOutcomeId].length) {
            indexEnd = ownerItems[msg.sender][winningOutcomeId].length;
        }

        for (uint i = _indexStart; i < indexEnd; i++) {
            Item storage item = items[ownerItems[msg.sender][winningOutcomeId][i] - 1];
            userWinTokens = safeAdd(userWinTokens, (safeMul(item.tokens, tokenPool) / winningOutcomeTokens));
            item.isWithdrawn = true;
        }

        if (userWinTokens > 0) {
            stox.transfer(msg.sender, userWinTokens);
        }

        ItemsWithdrawn(msg.sender, userWinTokens);
    }

    /*
        @dev After the event is resolved the event owner can pay tokens for all the winning items
        Alternatively the event owner / operator can choose that the users will need to withdraw the funds using the withdrawItems() function
    */    
    function payAllItems() public ownerOnly statusIs(Status.Resolved) {
        payAllItemsBulk(0, MAX_ITEMS_PAID);
    }

    /*
        @dev After the event is resolved the event owner can pay tokens for all the winning items
        Alternatively the event owner / operator can choose that the users will need to withdraw the funds using the withdrawItems() function

        @param _indexStart From which item index should we start paying
        @param _maxItems   How many items should we pay
    */    
    function payAllItemsBulk(uint _indexStart, uint _maxItems) public ownerOnly statusIs(Status.Resolved) greaterThanZero(_maxItems) {
        uint winningOutcomeTokens = outcomes[winningOutcomeId - 1].tokens;

        uint indexEnd = safeAdd(_indexStart, _maxItems);
        if (indexEnd > items.length) {
            indexEnd = items.length;
        }

        for (uint i = _indexStart; i < indexEnd; i++) {
            Item storage item = items[i];
            if ((item.id != 0) && (item.outcomeId == winningOutcomeId) && !item.isWithdrawn) {
                item.isWithdrawn = true;
                uint userWinTokens = safeMul(item.tokens, tokenPool) / winningOutcomeTokens;
                stox.transfer(item.owner, userWinTokens);
            }
        }

        ItemsPaid(safeAdd(_indexStart, 1), indexEnd);
    }

    /*
        @dev Returns the amount of tokens a user can withdraw from his item after the event is resolved

        @param _owner   Items owner

        @return         Token amount
    */ 
    function calculateUserItemsWithdrawValue(address _owner) external statusIs(Status.Resolved) constant returns (uint) {
        uint winningOutcomeTokens = outcomes[winningOutcomeId - 1].tokens;
        uint userWinTokens = 0;

        for (uint i = 0; i < ownerItems[_owner][winningOutcomeId].length; i++) {
            Item storage item = items[ownerItems[_owner][winningOutcomeId][i] - 1];
            userWinTokens = safeAdd(userWinTokens, (safeMul(item.tokens, tokenPool) / winningOutcomeTokens));
        }

        return (userWinTokens);
    }

    /*
        @dev Returns the amount of tokens a user invested in an outcome items

        @param _owner       Items owner
        @param _outcomeId   Outcome id

        @return             Token amount
    */ 
    function calculateUserItemsValue(address _owner, uint _outcomeId) external constant returns (uint) {
        uint userTokens = 0;

        for (uint i = 0; i < ownerItems[_owner][_outcomeId].length; i++) {
            Item storage item = items[ownerItems[_owner][_outcomeId][i] - 1];
            userTokens = safeAdd(userTokens, item.tokens);
        }

        return (userTokens);
    }

    /*
        @dev Allow the event owner to cancel the event.
        After the event is canceled users can no longer buy items, and are able to get a refund for their items tokens.
    */
    function cancel() public ownerOnly {
        require ((status == Status.Published) ||
            (status == Status.Paused));
        
        status = Status.Canceled;

        EventCanceled();
    }

    /*
        @dev Allow to event owner / operator to cancel the user's items and refund the tokens.

        @param _owner Items owner
        @param _outcomeId   Outcome to refund
    */
    function refundUser(address _owner, uint _outcomeId) public ownerOnly {
        require (status != Status.Resolved);
        
        performRefundBulk(_owner, _outcomeId, 0, MAX_ITEMS_REFUND);
        
    }

    /*
        @dev Allow to event owner / operator to cancel the user's items and refund the tokens.

        @param _owner Items owner
        @param _outcomeId   Outcome to refund
        @param _indexStart  From which item index should we refund
        @param _maxItems    How many items should we refund
    */
    function refundUserBulk(address _owner, uint _outcomeId, uint _indexStart, uint _maxItems) public ownerOnly {
        require (status != Status.Resolved);
        
        performRefundBulk(_owner, _outcomeId, _indexStart, _maxItems);
    }

    /*
        @dev Allow the user to cancel his items and refund the tokens he invested in items. 
        Can be called only after the event is canceled.

        @param _outcomeId   Outcome to refund
    */
    function getRefund(uint _outcomeId) public statusIs(Status.Canceled) {
        performRefundBulk(msg.sender, _outcomeId, 0, MAX_ITEMS_REFUND);
    }

    /*
        @dev Allow the user to cancel his items and refund the tokens he invested in items. 
        Can be called only after the event is canceled.

        @param _outcomeId   Outcome to refund
        @param _indexStart  From which item index should we refund
        @param _maxItems    How many items should we refund
    */
    function getRefundBulk(uint _outcomeId, uint _indexStart, uint _maxItems) public statusIs(Status.Canceled) {
        performRefundBulk(msg.sender, _outcomeId, _indexStart, _maxItems);
    }

    /*
        @dev Refund a specific user's items tokens and cancel the user's items.

        @param _owner       Items owner
        @param _outcomeId   Outcome to refund
        @param _indexStart  From which item index should we refund
        @param _maxItems    How many items should we refund
    */
    function performRefundBulk(address _owner, uint _outcomeId, uint _indexStart, uint _maxItems) private greaterThanZero(_maxItems) {
        require((tokenPool > 0) &&
                hasItems(_owner, _outcomeId));

        uint indexEnd = safeAdd(_indexStart, _maxItems);
        if (indexEnd > ownerItems[_owner][_outcomeId].length) {
            indexEnd = ownerItems[_owner][_outcomeId].length;
        }
        
        uint refundAmount = 0;

        for (uint itemPos = _indexStart; itemPos < indexEnd; itemPos++) {
            uint itemId = ownerItems[_owner][_outcomeId][itemPos];
            
            if (items[itemId - 1].tokens > 0) {
                outcomes[_outcomeId - 1].tokens = safeSub(outcomes[_outcomeId - 1].tokens, items[itemId - 1].tokens);
                refundAmount = safeAdd(refundAmount, items[itemId - 1].tokens);

                // After the token amount to refund is calculated - delete the user's tokens
                delete ownerItems[_owner][_outcomeId][itemPos];
                delete items[itemId - 1];
            }
        }

        if (refundAmount > 0) {
            tokenPool = safeSub(tokenPool, refundAmount);
            stox.transfer(_owner, refundAmount); // Refund the user
        }

        UserRefunded(_owner, _outcomeId, refundAmount);
    }

    /*
        @dev Allow to event owner / operator to cancel all the users items and refund their tokens.
    */
    function refundAllUsers() public ownerOnly statusIs(Status.Canceled) {
        refundItemsBulk(0, MAX_ITEMS_REFUND);
    }

    /*
        @dev Allow to event owner / operator to cancel the users items and refund their tokens.

        @param _indexStart From which item index should we start refunding
        @param _maxItems   How many items should refund
    */
    function refundItemsBulk(uint _indexStart, uint _maxItems) public ownerOnly statusIs(Status.Canceled) greaterThanZero(_maxItems) {
        require(tokenPool > 0);

        uint indexEnd = safeAdd(_indexStart, _maxItems);
        if (indexEnd > items.length) {
            indexEnd = items.length;
        }

        for (uint i = _indexStart; i < indexEnd; i++) {
            Item storage item = items[i];
            if (item.id != 0) {
                uint refundTokens = item.tokens;
                address owner = item.owner;
                delete items[i];

                stox.transfer(owner, refundTokens);
            }
        }

        tokenPool = 0;
        
        ItemsRefunded(safeAdd(_indexStart, 1), indexEnd);
    }

    /*
        @dev Allow the event owner to pause the event.
        After the event is paused users can no longer buy items until the event is republished
    */
    function pause() public statusIs(Status.Published) ownerOnly {
        status = Status.Paused;

        EventPaused();
    }

    /*
        @dev Returns the outcome name of a specific outcome id

        @param _outcomeId   Outcome id

        @return             Outcome name
    */
    function getOutcome(uint _outcomeId) public view returns (string) {
        require(isOutcomeExist(_outcomeId));

        return (outcomes[_outcomeId - 1].name);
    }

    /*
        @dev Returns true if the event contains a specific outcome id

        @param _outcomeId   Outcome id

        @return             true if the outcome exists
    */
    function isOutcomeExist(uint _outcomeId) private view returns (bool) {
        return ((_outcomeId > 0) && (_outcomeId <= outcomes.length));
    }

    /*
        @dev Returns true if the user's items of an outcome are all withdrawn

        @param _owner       Items owner
        @param _outcomeId   Outcome id

        @return             true if the user's items  on an outcome are all withdrawn
    */
    function areItemsWithdrawn(address _owner, uint _outcomeId, uint _indexStart, uint _maxItems) private view greaterThanZero(_maxItems) returns(bool) {
        uint indexEnd = safeAdd(_indexStart, _maxItems);
        if (indexEnd > ownerItems[_owner][_outcomeId].length) {
            indexEnd = ownerItems[_owner][_outcomeId].length;
        }

        for (uint i = _indexStart; i <= indexEnd; i++) {
            if (!items[ownerItems[_owner][_outcomeId][i] - 1].isWithdrawn) {
                return false;
            }
        }

        return true;
    }

    /*
        @dev Returns true if the user bought items of a specific outcome

        @param _owner       Items owner
        @param _outcomeId   Outcome id

        @return             true if the user bought items on a specific outcome
    */
    function hasItems(address _owner, uint _outcomeId) private view returns(bool) {
        return (ownerItems[_owner][_outcomeId].length > 0);
    }
}
