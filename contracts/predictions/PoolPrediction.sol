pragma solidity ^0.4.18;
import "../Ownable.sol";
import "../Utils.sol";
import "../oracles/Oracle.sol";
import "../token/IERC20Token.sol";
import "../modules/PredictionStatus.sol";
import "../modules/PredictionTiming.sol";
import "./PoolPredictionPrizeDistribution.sol";


/**
    @title Pool prediction contract - Pool predictions distributes tokens between all winners according to
    their proportional investment in the winning outcome. The prediction winning outcome is decided by the oracle.

    An example of a pool prediction
    ---------------------------
    An prediction has 3 different outcomes:
    1. Outcome1
    2. Outcome2
    3. Outcome3

    User A placed 100 tokens on Outcome1
    User B placed 300 tokens on Outcome1
    User C placed 100 tokens on Outcome2
    User D placed 100 tokens on Outcome3

    Total token pool: 600

    After the prediction ends, the oracle decides that the winning outcome is Outcome1

    Users can now withdraw from their units the following token amount:
    User A -> 150 tokens (100 / (100 + 300) * 600)
    User B -> 450 tokens (300 / (100 + 300) * 600)
    User C -> 0 tokens
    User D -> 0 tokens
 */
contract PoolPrediction is Ownable, Utils, PredictionStatus, PredictionTiming {

    /*
    *   Constants
    */
    uint private constant MAX_UNITS_WITHDRAWN   = 50;
    uint private constant MAX_UNITS_PAID        = 100;
    uint private constant MAX_UNITS_REFUND      = 50;


    /*
     *  Events
     */
    event UnitBought(address indexed _owner, uint indexed _outcomeId, uint indexed _unitId, uint _tokenAmount);
    event UnitsWithdrawn(address indexed _owner, uint _tokenAmount);
    event UnitsPaid(uint _unitIdStart, uint _unitIdEnd);
    event UserRefunded(address indexed _owner, uint _outcomeId, uint _tokenAmount);
    event UnitsRefunded(uint _unitIdStart, uint _unitIdEnd);
    event PredictionNameChanged(string _newName);
    event OracleChanged(address _oracle);
    event OutcomeAdded(uint indexed _outcomeId, string _name);

    /**
        @dev Check if the prediction has this outcome id

        @param _outcomeId Outcome to check
    */
    modifier outcomeValid(uint _outcomeId) {
        require(isOutcomeExist(_outcomeId));
        _;
    }

    struct Outcome {
        uint    id;         // Id will start at 1, and increase by 1 for every new outcome
        string  name;           
        uint    tokens;     // Total tokens used to buy units for this outcome
    }

    struct Unit {
        uint    id;         // Id will start at 1, and increase by 1 for every new unit
        uint    outcomeId;
        uint    tokens;
        bool    isWithdrawn;
        address owner;
    }

    struct OutcomeUnitTokens {
        uint    tokens;
        bool    isWithdrawn;
        bool    doesExist;
    }

    /*
     *  Members
     */
    string      public version = "0.1";
    string      public name;
    IERC20Token public stox;                // Stox ERC20 token
    PoolPredictionPrizeDistribution         public prizeDistribution;
    uint        public tokenPool;           // Total tokens used to buy units in this prediction
    address     public oracleAddress;       // When the prediction is resolved the oracle will tell the prediction who is the winning outcome
    uint        public winningOutcomeId;
    Outcome[]   public outcomes;
    Unit[]      public units;
    
    // Mapping to see all the units bought for each user and outcome (user address -> outcome id -> unit id[])
    mapping(address => mapping(uint => uint[])) public ownerUnits;

    // Mapping to see all the total tokens bought per outcome, per user (user address -> outcome id -> OutcomeUnitTokens)
    mapping(address => mapping(uint => OutcomeUnitTokens)) public ownerAccumulatedTokensPerOutcome;

    /*
        @dev constructor

        @param _owner                       Prediction owner / operator
        @param _oracle                      The oracle provides the winning outcome for the prediction
        @param _predictionEndTimeSeconds    Prediction end time
        @param _unitBuyingEndTimeSeconds    Unit buying end time
        @param _name                        Prediction name
        @param _stox                        Stox ERC20 token address
    */
    function PoolPrediction(address _owner,
            address _oracle,
            uint _predictionEndTimeSeconds,
            uint _unitBuyingEndTimeSeconds,
            string _name,
            IERC20Token _stox,
            PoolPredictionPrizeDistribution _prizeDistribution)
            public 
            validAddress(_oracle)
            validAddress(_owner)
            validAddress(_stox)
            validAddress(_prizeDistribution)
            greaterThanZero(_predictionEndTimeSeconds)
            greaterThanZero(_unitBuyingEndTimeSeconds)
            notEmpty(_name)
            Ownable(_owner)
            PredictionStatus(_owner)
            PredictionTiming(_owner,_predictionEndTimeSeconds,_unitBuyingEndTimeSeconds)
            {

        oracleAddress = _oracle;
        name = _name;
        stox = _stox;
        prizeDistribution = _prizeDistribution;
    }

    /*
        @dev Allow the prediction owner to change add a new outcome to the prediction

        @param _name Outcome name
    */
    function addOutcome(string _name) public ownerOnly notEmpty(_name) statusIs(Status.Initializing) {
        uint outcomeId = safeAdd(outcomes.length, 1);
        outcomes.push(Outcome(outcomeId, _name, 0));

        OutcomeAdded(outcomeId, _name);
    }

    /*
        @dev Allow the prediction owner to publish the prediction - Users can now buy unit on the various outcomes.
    */
    function publish() public ownerOnly {
        require (outcomes.length > 1);

        PredictionStatus.publish();
    }

    /*
        @dev Allow the prediction owner to change unit buying end time when prediction is initializing or paused

        @param _newUnitBuyingEndTimeSeconds Unit buying end time
    */
    function setUnitBuyingEndTime(uint _newUnitBuyingEndTimeSeconds)  ownerOnly {
         require ((status == Status.Initializing) || (status == Status.Paused));

         PredictionTiming.setUnitBuyingEndTime(_newUnitBuyingEndTimeSeconds);
    }

    /*
        @dev Allow the prediction owner to change the prediction end time when prediction is initializing or paused

        @param _newPredictionEndTimeSeconds Prediction end time
    */
    function setPredictionEndTime(uint _newPredictionEndTimeSeconds)  ownerOnly {
         require ((status == Status.Initializing) || (status == Status.Paused));

         PredictionTiming.setPredictionEndTime(_newPredictionEndTimeSeconds);
    }

    /*
        @dev Allow the prediction owner to change the name

        @param _newName Prediction name
    */
    function setPredictionName(string _newName) notEmpty(_newName) external ownerOnly {
        name = _newName;

        PredictionNameChanged(_newName);
    }

    /*
        @dev Allow the prediction owner to change the oracle address

        @param _oracle Oracle address
    */
    function setOracle(address _oracle) validAddress(_oracle) notThis(_oracle) external ownerOnly {
        require (status != Status.Resolved);

        oracleAddress = _oracle;

        OracleChanged(oracleAddress);
    }

    /*
        @dev Allow any user to buy an unit on a specific outcome. note that users can buy multiple units on a specific outcome.
        Before calling buyUnit the user should first call the approve(thisPredictionAddress, tokenAmount) on the
        stox token (or any other ERC20 token).

        @param _owner       The unit owner
        @param _tokenAmount The amount of tokens invested in this unit
        @param _outcomeId   The outcome the user predicts.
    */
    function buyUnitFor(address _owner, uint _tokenAmount, uint _outcomeId)
            public
            statusIs(Status.Published)
            validAddress(_owner)
            greaterThanZero(_tokenAmount)
            outcomeValid(_outcomeId) {
        
        require(
            unitBuyingEndTimeSeconds > now);

        tokenPool = safeAdd(tokenPool, _tokenAmount);
        outcomes[_outcomeId - 1].tokens = safeAdd(outcomes[_outcomeId - 1].tokens, _tokenAmount);

        uint unitId = safeAdd(units.length, 1);
        units.push(Unit(unitId, _outcomeId, _tokenAmount, false, _owner));
        ownerUnits[_owner][_outcomeId].push(unitId);

        if (ownerAccumulatedTokensPerOutcome[_owner][_outcomeId].tokens > 0) {
            ownerAccumulatedTokensPerOutcome[_owner][_outcomeId].tokens = safeAdd(ownerAccumulatedTokensPerOutcome[_owner][_outcomeId].tokens, _tokenAmount); 
        }
        else {
             ownerAccumulatedTokensPerOutcome[_owner][_outcomeId] = OutcomeUnitTokens(_tokenAmount, false, true);
        }
        
        assert(stox.transferFrom(_owner, this, _tokenAmount));
        
        UnitBought(_owner, _outcomeId, unitId, _tokenAmount);
    }

    /*
        @dev Allow any user to buy an unit on a specific outcome.
        Before calling buyUnit the user should first call the approve(thisPredictionAddress, tokenAmount) on the
        stox token (or any other ERC20 token).

        @param _tokenAmount The amount of tokens invested in this unit
        @param _outcomeId   The outcome the user predicts.
    */
    function buyUnit(uint _tokenAmount, uint _outcomeId) external  {
        buyUnitFor(msg.sender, _tokenAmount, _outcomeId);
    }

    /*
        @dev Allow the prediction owner to resolve the prediction.
        Before calling resolve() the oracle owner should first set the prediction outcome by calling setOutcome(thisPredictionAddress, winningOutcomeId)
        in the Oracle contract.
    */
    function resolve() public /*statusIs(Status.Published)*/ ownerOnly {
        require(isOutcomeExist((Oracle(oracleAddress)).getOutcome(this)) &&
            (unitBuyingEndTimeSeconds < now));

        winningOutcomeId = (Oracle(oracleAddress)).getOutcome(this);

        // In the very unlikely prediction that no one bought an unit on the winning outcome - throw exception.
        // The only units for the prediction operator is to cancel the prediction and refund the money, or change the prediction end time)
        assert(outcomes[winningOutcomeId - 1].tokens > 0);

        PredictionStatus.resolve(oracleAddress,winningOutcomeId);
        
        //status = Status.Resolved;

        //PredictionResolved(oracleAddress, winningOutcomeId);
    }

    /*
        @dev After the prediction is resolved the user can withdraw tokens from his winning units
        Alternatively the prediction owner / operator can choose to pay all the users himself using the payAllUnits() function
    */
    function withdrawUnits() public statusIs(Status.Resolved) {
        require(ownerUnits[msg.sender][winningOutcomeId].length <= MAX_UNITS_WITHDRAWN);
        withdrawUnitsBulk(0, ownerUnits[msg.sender][winningOutcomeId].length);
    }

    /*
        @dev After the prediction is resolved the user can withdraw tokens from his winning units
        Alternatively the prediction owner / operator can choose to pay all the users himself using the payAllUnits() function

        @param _indexStart From which unit index should we start withdrawing
        @param _maxUnits   How many units should we withdraw
    */
    function withdrawUnitsBulk(uint _indexStart, uint _maxUnits) public statusIs(Status.Resolved) greaterThanZero(_maxUnits) {
        require(
            (hasUnits(msg.sender, winningOutcomeId) &&
            (!areUnitsWithdrawn(msg.sender, winningOutcomeId, _indexStart, _maxUnits))));

        uint winningOutcomeTokens = outcomes[winningOutcomeId - 1].tokens;
        uint userWinTokens = 0;

        uint indexEnd = safeAdd(_indexStart, _maxUnits);
        if (indexEnd > ownerUnits[msg.sender][winningOutcomeId].length) {
            indexEnd = ownerUnits[msg.sender][winningOutcomeId].length;
        }

        for (uint i = _indexStart; i < indexEnd; i++) {
            Unit storage unit = units[ownerUnits[msg.sender][winningOutcomeId][i] - 1];
            userWinTokens = safeAdd(userWinTokens, (safeMul(unit.tokens, tokenPool) / winningOutcomeTokens));
            unit.isWithdrawn = true;
        }

        userWinTokens = prizeDistribution.calculateWithdrawalAmount(ownerAccumulatedTokensPerOutcome[msg.sender][winningOutcomeId].tokens,winningOutcomeTokens,tokenPool);

        if (userWinTokens > 0) {
            stox.transfer(msg.sender, userWinTokens);
        }

        ownerAccumulatedTokensPerOutcome[msg.sender][winningOutcomeId].isWithdrawn = true;

        UnitsWithdrawn(msg.sender, userWinTokens);
    }

    /*
        @dev After the prediction is resolved the prediction owner can pay tokens for all the winning units
        Alternatively the prediction owner / operator can choose that the users will need to withdraw the funds using the withdrawUnits() function
    */    
    function payAllUnits() public ownerOnly statusIs(Status.Resolved) {
        require(units.length <= MAX_UNITS_PAID);
        payAllUnitsBulk(0, units.length);
    }

    /*
        @dev After the prediction is resolved the prediction owner can pay tokens for all the winning units
        Alternatively the prediction owner / operator can choose that the users will need to withdraw the funds using the withdrawUnits() function

        @param _indexStart From which unit index should we start paying
        @param _maxUnits   How many units should we pay
    */    
    function payAllUnitsBulk(uint _indexStart, uint _maxUnits) public ownerOnly statusIs(Status.Resolved) greaterThanZero(_maxUnits) {
        uint winningOutcomeTokens = outcomes[winningOutcomeId - 1].tokens;

        uint indexEnd = safeAdd(_indexStart, _maxUnits);
        if (indexEnd > units.length) {
            indexEnd = units.length;
        }

        for (uint i = _indexStart; i < indexEnd; i++) {
            Unit storage unit = units[i];
            if ((unit.id != 0) && (unit.outcomeId == winningOutcomeId) && !unit.isWithdrawn) {
                unit.isWithdrawn = true;
                uint userWinTokens = safeMul(unit.tokens, tokenPool) / winningOutcomeTokens;
                stox.transfer(unit.owner, userWinTokens);
            }
        }

        UnitsPaid(safeAdd(_indexStart, 1), indexEnd);
    }

    /*
        @dev Returns the amount of tokens a user can withdraw from his unit after the prediction is resolved

        @param _owner   Units owner

        @return         Token amount
    */ 
    function calculateUserUnitsWithdrawValue(address _owner) external statusIs(Status.Resolved) constant returns (uint) {
        uint winningOutcomeTokens = outcomes[winningOutcomeId - 1].tokens;
        uint userWinTokens = 0;

        for (uint i = 0; i < ownerUnits[_owner][winningOutcomeId].length; i++) {
            Unit storage unit = units[ownerUnits[_owner][winningOutcomeId][i] - 1];
            userWinTokens = safeAdd(userWinTokens, (safeMul(unit.tokens, tokenPool) / winningOutcomeTokens));
        }

        return (userWinTokens);
    }

    /*
        @dev Returns the amount of tokens a user invested in an outcome units

        @param _owner       Units owner
        @param _outcomeId   Outcome id

        @return             Token amount
    */ 
    function calculateUserUnitsValue(address _owner, uint _outcomeId) external constant returns (uint) {
        uint userTokens = 0;

        for (uint i = 0; i < ownerUnits[_owner][_outcomeId].length; i++) {
            Unit storage unit = units[ownerUnits[_owner][_outcomeId][i] - 1];
            userTokens = safeAdd(userTokens, unit.tokens);
        }

        return (userTokens);
    }

    
    /*
        @dev Allow to prediction owner / operator to cancel the user's units and refund the tokens.

        @param _owner Units owner
        @param _outcomeId   Outcome to refund
    */
    function refundUser(address _owner, uint _outcomeId) public ownerOnly {
        require ((status != Status.Resolved) &&
                (ownerUnits[_owner][_outcomeId].length <= MAX_UNITS_REFUND));
        
        performRefundBulk(_owner, _outcomeId, 0, ownerUnits[_owner][_outcomeId].length);
        
    }

    /*
        @dev Allow to prediction owner / operator to cancel the user's units and refund the tokens.

        @param _owner Units owner
        @param _outcomeId   Outcome to refund
        @param _indexStart  From which unit index should we refund
        @param _maxUnits    How many units should we refund
    */
    function refundUserBulk(address _owner, uint _outcomeId, uint _indexStart, uint _maxUnits) public ownerOnly {
        require (status != Status.Resolved);
        
        performRefundBulk(_owner, _outcomeId, _indexStart, _maxUnits);
    }

    /*
        @dev Allow the user to cancel his units and refund the tokens he invested in units.
        Can be called only after the prediction is canceled.

        @param _outcomeId   Outcome to refund
    */
    function getRefund(uint _outcomeId) public statusIs(Status.Canceled) {
        require(ownerUnits[msg.sender][_outcomeId].length <= MAX_UNITS_REFUND);
        performRefundBulk(msg.sender, _outcomeId, 0, ownerUnits[msg.sender][_outcomeId].length);
    }

    /*
        @dev Allow the user to cancel his units and refund the tokens he invested in units.
        Can be called only after the prediction is canceled.

        @param _outcomeId   Outcome to refund
        @param _indexStart  From which unit index should we refund
        @param _maxUnits    How many units should we refund
    */
    function getRefundBulk(uint _outcomeId, uint _indexStart, uint _maxUnits) public statusIs(Status.Canceled) {
        performRefundBulk(msg.sender, _outcomeId, _indexStart, _maxUnits);
    }

    /*
        @dev Refund a specific user's units tokens and cancel the user's units.

        @param _owner       Units owner
        @param _outcomeId   Outcome to refund
        @param _indexStart  From which unit index should we refund
        @param _maxUnits    How many units should we refund
    */
    function performRefundBulk(address _owner, uint _outcomeId, uint _indexStart, uint _maxUnits) private greaterThanZero(_maxUnits) {
        require((tokenPool > 0) &&
                hasUnits(_owner, _outcomeId));

        uint indexEnd = safeAdd(_indexStart, _maxUnits);
        if (indexEnd > ownerUnits[_owner][_outcomeId].length) {
            indexEnd = ownerUnits[_owner][_outcomeId].length;
        }
        
        uint refundAmount = 0;

        for (uint unitPos = _indexStart; unitPos < indexEnd; unitPos++) {
            uint unitId = ownerUnits[_owner][_outcomeId][unitPos];
            
            if (units[unitId - 1].tokens > 0) {
                outcomes[_outcomeId - 1].tokens = safeSub(outcomes[_outcomeId - 1].tokens, units[unitId - 1].tokens);
                refundAmount = safeAdd(refundAmount, units[unitId - 1].tokens);

                // After the token amount to refund is calculated - delete the user's tokens
                delete ownerUnits[_owner][_outcomeId][unitPos];
                delete units[unitId - 1];
            }
        }

        if (refundAmount > 0) {
            tokenPool = safeSub(tokenPool, refundAmount);
            stox.transfer(_owner, refundAmount); // Refund the user
        }

        UserRefunded(_owner, _outcomeId, refundAmount);
    }

    /*
        @dev Allow to prediction owner / operator to cancel all the users units and refund their tokens.
    */
    function refundAllUsers() public ownerOnly statusIs(Status.Canceled) {
        require(units.length <= MAX_UNITS_REFUND);
        refundUnitsBulk(0, units.length);
    }

    /*
        @dev Allow to prediction owner / operator to cancel the users units and refund their tokens.

        @param _indexStart From which unit index should we start refunding
        @param _maxUnits   How many units should refund
    */
    function refundUnitsBulk(uint _indexStart, uint _maxUnits) public ownerOnly statusIs(Status.Canceled) greaterThanZero(_maxUnits) {
        require(tokenPool > 0);

        uint indexEnd = safeAdd(_indexStart, _maxUnits);
        if (indexEnd > units.length) {
            indexEnd = units.length;
        }

        for (uint i = _indexStart; i < indexEnd; i++) {
            Unit storage unit = units[i];
            if (unit.id != 0) {
                uint refundTokens = unit.tokens;
                address owner = unit.owner;
                delete units[i];

                stox.transfer(owner, refundTokens);
            }
        }

        tokenPool = 0;
        
        UnitsRefunded(safeAdd(_indexStart, 1), indexEnd);
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
        @dev Returns true if the prediction contains a specific outcome id

        @param _outcomeId   Outcome id

        @return             true if the outcome exists
    */
    function isOutcomeExist(uint _outcomeId) private view returns (bool) {
        return ((_outcomeId > 0) && (_outcomeId <= outcomes.length));
    }

    /*
        @dev Returns true if the user's units of an outcome are all withdrawn

        @param _owner       Units owner
        @param _outcomeId   Outcome id

        @return             true if the user's units  on an outcome are all withdrawn
    */
    function areUnitsWithdrawn(address _owner, uint _outcomeId, uint _indexStart, uint _maxUnits) private view greaterThanZero(_maxUnits) returns(bool) {
        uint indexEnd = safeAdd(_indexStart, _maxUnits);
        if (indexEnd > ownerUnits[_owner][_outcomeId].length) {
            indexEnd = ownerUnits[_owner][_outcomeId].length;
        }

        for (uint i = _indexStart; i <= indexEnd; i++) {
            if (!units[ownerUnits[_owner][_outcomeId][i] - 1].isWithdrawn) {
                return false;
            }
        }

        return true;
    }

    /*
        @dev Returns true if the user bought units of a specific outcome

        @param _owner       Units owner
        @param _outcomeId   Outcome id

        @return             true if the user bought units on a specific outcome
    */
    function hasUnits(address _owner, uint _outcomeId) private view returns(bool) {
        return (ownerUnits[_owner][_outcomeId].length > 0);
    }
}
