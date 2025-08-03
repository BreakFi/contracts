// SPDX-License-Identifier: ISC
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "./interfaces/IReputationRegistry.sol";
import "./interfaces/IERC20Extended.sol";
import "./libraries/ParameterKeys.sol";
import "./libraries/Events.sol";
import "./libraries/EventTypes.sol";

/**
 * @title ReputationRegistry
 * @notice A decentralized reputation system for cross-platform user reputation tracking.
 * @dev This contract enables multiple platforms to submit and access reputation data
 *      in a standardized, transparent manner using a two-tier authorization model.
 */
contract ReputationRegistry is IReputationRegistry, ReentrancyGuard, Pausable, AccessControl {
    using SafeERC20 for IERC20;

    // ============ ROLES ============
    bytes32 public constant DAO_ROLE = keccak256("DAO_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // ============ IMPORT TYPES FROM INTERFACE ============
    // Note: Data structures are defined in IReputationRegistry interface

    // ============ STORAGE ============

    // Main contract registry
    mapping(address => ContractInfo) public contractRegistry;
    
    // Credit balances for prepaid contracts
    mapping(address => uint256) public creditBalances;
    
    // User statuses: contract -> user -> status
    mapping(address => mapping(address => UserStatus)) public userStatuses;
    
    // Reputation events: contract -> subject -> event_type -> events[]
    mapping(address => mapping(address => mapping(bytes32 => ReputationEvent[]))) private reputationEvents;
    
    // Event existence check (prevent duplicates)
    mapping(bytes32 => bool) public eventExists;

    // Parameters
    mapping(bytes32 => uint256) public parameters;

    // Revenue tracking
    uint256 public totalFeesCollected;
    uint256 public totalCreditsAdded;


    // USDC token for payments
    IERC20 public immutable usdcToken;

    // ============ EVENTS ============
    // Note: Events are defined in IReputationRegistry interface

    // ============ MODIFIERS ============

    modifier onlyDAO() {
        require(hasRole(DAO_ROLE, msg.sender), "ReputationRegistry: caller is not DAO");
        _;
    }

    modifier onlyRegisteredContract() {
        require(contractRegistry[msg.sender].active, "ReputationRegistry: caller not registered or inactive");
        _;
    }

    modifier validAuthTier(AuthTier tier) {
        require(tier == AuthTier.PREPAID || tier == AuthTier.DAO_APPROVED, "ReputationRegistry: invalid auth tier");
        _;
    }

    // ============ CONSTRUCTOR ============

    constructor(
        address defaultAdmin,
        address initialDAO,
        address initialPauser,
        address _usdcToken
    ) {
        require(_usdcToken != address(0), "ReputationRegistry: invalid USDC token address");
        
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(DAO_ROLE, initialDAO);
        _grantRole(PAUSER_ROLE, initialPauser);

        usdcToken = IERC20(_usdcToken);

        // Initialize default parameters
        _initializeParameters();
    }

    // ============ INITIALIZATION ============

    function _initializeParameters() internal {
        (bytes32[] memory keys, uint256[] memory values) = ParameterKeys.getDefaultReputationParameters();
        for (uint256 i = 0; i < keys.length; i++) {
            parameters[keys[i]] = values[i];
        }
    }

    // ============ REGISTRATION FUNCTIONS ============

    /**
     * @notice Register a prepaid contract with initial credits
     * @param initialCredits Amount of USDC to deposit (must be >= minimum)
     * @param name Human-readable contract name
     */
    function registerPrepaidContract(
        uint256 initialCredits,
        string calldata name
    ) external override nonReentrant whenNotPaused {
        require(bytes(name).length > 0, "ReputationRegistry: name cannot be empty");
        require(!contractRegistry[msg.sender].active, "ReputationRegistry: contract already registered");
        
        uint256 minDeposit = parameters[ParameterKeys.REGISTRATION_DEPOSIT];
        require(initialCredits >= minDeposit, "ReputationRegistry: insufficient initial credits");

        // Transfer USDC from sender
        usdcToken.safeTransferFrom(msg.sender, address(this), initialCredits);

        // Register contract
        uint32 defaultWeight = uint32(parameters[ParameterKeys.DEFAULT_CONTRACT_WEIGHT]);
        uint32 currentTime = uint32(block.timestamp);

        contractRegistry[msg.sender] = ContractInfo({
            tier: AuthTier.PREPAID,
            weight: defaultWeight,
            registeredAt: currentTime,
            submissionCount: 0,
            active: true,
            name: name
        });

        // Add credits
        creditBalances[msg.sender] = initialCredits;
        totalCreditsAdded += initialCredits;

        // Track revenue
        uint256 today = block.timestamp / 86400;

        totalFeesCollected += initialCredits;

        emit Events.ContractRegistered(msg.sender, uint8(AuthTier.PREPAID), name, initialCredits);
        emit Events.CreditsAdded(msg.sender, initialCredits, initialCredits);
    }

    /**
     * @notice DAO-approved contract registration (free)
     * @param contractAddress Address of the contract to approve
     * @param weight Reputation weight (0-100)
     * @param name Human-readable contract name
     */
    function approveContract(
        address contractAddress,
        uint32 weight,
        string calldata name
    ) external override onlyDAO {
        require(contractAddress != address(0), "ReputationRegistry: invalid contract address");
        require(bytes(name).length > 0, "ReputationRegistry: name cannot be empty");
        require(!contractRegistry[contractAddress].active, "ReputationRegistry: contract already registered");
        require(weight <= parameters[ParameterKeys.MAX_CONTRACT_WEIGHT], "ReputationRegistry: weight exceeds maximum");

        uint32 currentTime = uint32(block.timestamp);

        contractRegistry[contractAddress] = ContractInfo({
            tier: AuthTier.DAO_APPROVED,
            weight: weight,
            registeredAt: currentTime,
            submissionCount: 0,
            active: true,
            name: name
        });

        emit Events.ContractApproved(contractAddress, weight, name);
    }

    /**
     * @notice Revoke a contract's registration
     * @param contractAddress Address of the contract to revoke
     * @param reason Reason for revocation
     */
    function revokeContract(
        address contractAddress,
        string calldata reason
    ) external override onlyDAO {
        require(contractRegistry[contractAddress].active, "ReputationRegistry: contract not active");
        require(bytes(reason).length > 0, "ReputationRegistry: reason required");

        contractRegistry[contractAddress].active = false;

        emit Events.ContractRevoked(contractAddress, reason);
    }

    /**
     * @notice Add credits to a prepaid contract
     * @param amount Amount of USDC to add as credits
     */
    function addCredits(uint256 amount) external override nonReentrant whenNotPaused {
        require(amount > 0, "ReputationRegistry: amount must be positive");
        require(contractRegistry[msg.sender].active, "ReputationRegistry: contract not registered or inactive");
        require(contractRegistry[msg.sender].tier == AuthTier.PREPAID, "ReputationRegistry: only prepaid contracts can add credits");

        // Check max credit balance
        uint256 maxCredits = parameters[ParameterKeys.MAX_CREDIT_BALANCE];
        require(creditBalances[msg.sender] + amount <= maxCredits, "ReputationRegistry: would exceed max credit balance");

        // Transfer USDC from sender
        usdcToken.safeTransferFrom(msg.sender, address(this), amount);

        // Add credits
        creditBalances[msg.sender] += amount;
        totalCreditsAdded += amount;

        // Track revenue
        uint256 today = block.timestamp / 86400;

        totalFeesCollected += amount;

        emit Events.CreditsAdded(msg.sender, amount, creditBalances[msg.sender]);
    }

    // ============ DATA SUBMISSION FUNCTIONS ============

    /**
     * @notice Submit a reputation event
     * @param subject User being rated
     * @param eventType Type of event (standardized)
     * @param value Rating/score value
     * @param eventId Unique event identifier
     * @param metadata Additional event data
     */
    function submitReputationEvent(
        address subject,
        bytes32 eventType,
        uint256 value,
        bytes32 eventId,
        bytes calldata metadata
    ) external override onlyRegisteredContract nonReentrant whenNotPaused {
        require(subject != address(0), "ReputationRegistry: invalid subject address");
        require(eventType != bytes32(0), "ReputationRegistry: invalid event type");
        require(!eventExists[eventId], "ReputationRegistry: event already exists");

        ContractInfo storage contractInfo = contractRegistry[msg.sender];

        // Handle payment for prepaid contracts
        if (contractInfo.tier == AuthTier.PREPAID) {
            uint256 submissionFee = parameters[ParameterKeys.PREPAID_SUBMISSION_FEE];
            require(creditBalances[msg.sender] >= submissionFee, "ReputationRegistry: insufficient credits");
            
            creditBalances[msg.sender] -= submissionFee;
            totalFeesCollected += submissionFee; // Track collected fees
            emit Events.CreditsDeducted(msg.sender, submissionFee, creditBalances[msg.sender]);
        }

        // Store the event
        ReputationEvent memory newEvent = ReputationEvent({
            subject: subject,
            timestamp: uint32(block.timestamp),
            value: uint32(value),
            blockNumber: uint32(block.number)
        });

        reputationEvents[msg.sender][subject][eventType].push(newEvent);
        eventExists[eventId] = true;
        contractInfo.submissionCount++;

        emit Events.ReputationEventSubmitted(msg.sender, subject, eventType, value, eventId);
    }

    /**
     * @notice Update user status for the calling contract
     * @param user User to update status for
     * @param statusValue Numeric status value
     * @param expiryDate Status expiry timestamp (0 = no expiry)
     */
    function updateUserStatus(
        address user,
        uint32 statusValue,
        uint32 expiryDate
    ) external override onlyRegisteredContract nonReentrant whenNotPaused {
        require(user != address(0), "ReputationRegistry: invalid user address");

        ContractInfo storage contractInfo = contractRegistry[msg.sender];

        // Handle payment for prepaid contracts
        if (contractInfo.tier == AuthTier.PREPAID) {
            uint256 submissionFee = parameters[ParameterKeys.PREPAID_SUBMISSION_FEE];
            require(creditBalances[msg.sender] >= submissionFee, "ReputationRegistry: insufficient credits");
            
            creditBalances[msg.sender] -= submissionFee;
            totalFeesCollected += submissionFee; // Track collected fees
            emit Events.CreditsDeducted(msg.sender, submissionFee, creditBalances[msg.sender]);
        }

        // Update user status
        userStatuses[msg.sender][user] = UserStatus({
            statusValue: statusValue,
            updatedAt: uint32(block.timestamp),
            expiryDate: expiryDate,
            active: true
        });

        emit Events.UserStatusUpdated(msg.sender, user, statusValue, expiryDate, true);
    }

    /**
     * @notice Batch submit reputation events (DAO-approved contracts only)
     * @param subjects Array of users being rated
     * @param eventTypes Array of event types
     * @param values Array of rating/score values
     * @param eventIds Array of unique event identifiers
     */
    function batchSubmitEvents(
        address[] calldata subjects,
        bytes32[] calldata eventTypes,
        uint256[] calldata values,
        bytes32[] calldata eventIds
    ) external override onlyRegisteredContract nonReentrant whenNotPaused {
        require(subjects.length == eventTypes.length, "ReputationRegistry: array length mismatch");
        require(subjects.length == values.length, "ReputationRegistry: array length mismatch");
        require(subjects.length == eventIds.length, "ReputationRegistry: array length mismatch");
        require(subjects.length > 0, "ReputationRegistry: empty arrays");
        
        ContractInfo storage contractInfo = contractRegistry[msg.sender];
        require(contractInfo.tier == AuthTier.DAO_APPROVED, "ReputationRegistry: only DAO-approved contracts can batch submit");
        
        uint256 maxBatchSize = parameters[ParameterKeys.MAX_BATCH_SIZE];
        require(subjects.length <= maxBatchSize, "ReputationRegistry: batch size exceeds maximum");

        uint32 currentTime = uint32(block.timestamp);
        uint32 currentBlock = uint32(block.number);

        for (uint256 i = 0; i < subjects.length; i++) {
            require(subjects[i] != address(0), "ReputationRegistry: invalid subject address");
            require(eventTypes[i] != bytes32(0), "ReputationRegistry: invalid event type");
            require(!eventExists[eventIds[i]], "ReputationRegistry: event already exists");

            // Store the event
            ReputationEvent memory newEvent = ReputationEvent({
                subject: subjects[i],
                timestamp: currentTime,
                value: uint32(values[i]),
                blockNumber: currentBlock
            });

            reputationEvents[msg.sender][subjects[i]][eventTypes[i]].push(newEvent);
            eventExists[eventIds[i]] = true;

            emit ReputationEventSubmitted(msg.sender, subjects[i], eventTypes[i], values[i]);
        }

        contractInfo.submissionCount += uint32(subjects.length);
    }

    /**
     * @notice Batch update user statuses (DAO-approved contracts only)
     * @param users Array of users to update
     * @param statusValues Array of status values
     * @param expiryDates Array of expiry dates
     */
    function batchUpdateUserStatuses(
        address[] calldata users,
        uint32[] calldata statusValues,
        uint32[] calldata expiryDates
    ) external override onlyRegisteredContract nonReentrant whenNotPaused {
        require(users.length == statusValues.length, "ReputationRegistry: array length mismatch");
        require(users.length == expiryDates.length, "ReputationRegistry: array length mismatch");
        require(users.length > 0, "ReputationRegistry: empty arrays");
        
        ContractInfo storage contractInfo = contractRegistry[msg.sender];
        require(contractInfo.tier == AuthTier.DAO_APPROVED, "ReputationRegistry: only DAO-approved contracts can batch update");
        
        uint256 maxBatchSize = parameters[ParameterKeys.MAX_BATCH_SIZE];
        require(users.length <= maxBatchSize, "ReputationRegistry: batch size exceeds maximum");

        uint32 currentTime = uint32(block.timestamp);

        for (uint256 i = 0; i < users.length; i++) {
            require(users[i] != address(0), "ReputationRegistry: invalid user address");

            userStatuses[msg.sender][users[i]] = UserStatus({
                statusValue: statusValues[i],
                updatedAt: currentTime,
                expiryDate: expiryDates[i],
                active: true
            });

            emit UserStatusUpdated(msg.sender, users[i], statusValues[i], expiryDates[i]);
        }
    }

    // ============ VIEW FUNCTIONS ============

    /**
     * @notice Get reputation events for a user from a specific contract
     * @param contractAddr Contract address
     * @param subject User address
     * @param eventType Event type
     * @return Array of reputation events
     */
    function getReputationEvents(
        address contractAddr,
        address subject,
        bytes32 eventType
    ) external view override returns (ReputationEvent[] memory) {
        return reputationEvents[contractAddr][subject][eventType];
    }

    /**
     * @notice Get count of events for a user from a specific contract
     * @param contractAddr Contract address
     * @param subject User address
     * @param eventType Event type
     * @return Number of events
     */
    function getEventCount(
        address contractAddr,
        address subject,
        bytes32 eventType
    ) external view override returns (uint256) {
        return reputationEvents[contractAddr][subject][eventType].length;
    }

    /**
     * @notice Get recent events with limit
     * @param contractAddr Contract address
     * @param subject User address
     * @param eventType Event type
     * @param limit Maximum number of events to return
     * @return Array of recent reputation events
     */
    function getRecentEvents(
        address contractAddr,
        address subject,
        bytes32 eventType,
        uint256 limit
    ) external view override returns (ReputationEvent[] memory) {
        ReputationEvent[] storage allEvents = reputationEvents[contractAddr][subject][eventType];
        uint256 totalEvents = allEvents.length;
        
        if (totalEvents == 0 || limit == 0) {
            return new ReputationEvent[](0);
        }
        
        uint256 returnLength = limit > totalEvents ? totalEvents : limit;
        ReputationEvent[] memory result = new ReputationEvent[](returnLength);
        
        // Return the most recent events (from the end of the array)
        uint256 startIndex = totalEvents - returnLength;
        for (uint256 i = 0; i < returnLength; i++) {
            result[i] = allEvents[startIndex + i];
        }
        
        return result;
    }

    /**
     * @notice Get events with pagination
     * @param contractAddr Contract address
     * @param subject User address
     * @param eventType Event type
     * @param offset Starting index
     * @param limit Maximum number of events to return
     * @return events Array of reputation events
     * @return total Total number of events available
     * @return hasMore Whether there are more events available
     */
    function getEventsPaginated(
        address contractAddr,
        address subject,
        bytes32 eventType,
        uint256 offset,
        uint256 limit
    ) external view override returns (ReputationEvent[] memory events, uint256 total, bool hasMore) {
        ReputationEvent[] storage allEvents = reputationEvents[contractAddr][subject][eventType];
        total = allEvents.length;
        
        if (total == 0 || offset >= total || limit == 0) {
            return (new ReputationEvent[](0), total, false);
        }
        
        uint256 remainingEvents = total - offset;
        uint256 returnLength = limit > remainingEvents ? remainingEvents : limit;
        events = new ReputationEvent[](returnLength);
        
        for (uint256 i = 0; i < returnLength; i++) {
            events[i] = allEvents[offset + i];
        }
        
        hasMore = (offset + returnLength) < total;
        
        return (events, total, hasMore);
    }

    /**
     * @notice Get contract information
     * @param contractAddr Contract address
     * @return Contract information struct
     */
    function getContractInfo(address contractAddr) external view override returns (ContractInfo memory) {
        return contractRegistry[contractAddr];
    }

    /**
     * @notice Get user status for a specific contract
     * @param contractAddr Contract address
     * @param user User address
     * @return User status struct
     */
    function getUserStatus(address contractAddr, address user) external view override returns (UserStatus memory) {
        return userStatuses[contractAddr][user];
    }

    /**
     * @notice Check if user status is active and not expired
     * @param contractAddr Contract address
     * @param user User address
     * @return True if status is active and not expired
     */
    function isStatusActive(address contractAddr, address user) external view override returns (bool) {
        UserStatus memory status = userStatuses[contractAddr][user];
        if (!status.active) return false;
        if (status.expiryDate == 0) return true; // No expiry
        return block.timestamp <= status.expiryDate;
    }

    /**
     * @notice Get multiple user statuses in batch
     * @param contractAddr Contract address
     * @param users Array of user addresses
     * @return Array of user statuses
     */
    function getBatchUserStatuses(
        address contractAddr,
        address[] calldata users
    ) external view override returns (UserStatus[] memory) {
        UserStatus[] memory statuses = new UserStatus[](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            statuses[i] = userStatuses[contractAddr][users[i]];
        }
        return statuses;
    }

    /**
     * @notice Check if a contract is registered and active
     * @param contractAddr Contract address
     * @return True if registered and active
     */
    function isContractRegistered(address contractAddr) external view override returns (bool) {
        return contractRegistry[contractAddr].active;
    }

    /**
     * @notice Get credit balance for a contract
     * @param contractAddr Contract address
     * @return Current credit balance
     */
    function getCreditBalance(address contractAddr) external view override returns (uint256) {
        return creditBalances[contractAddr];
    }

    /**
     * @notice Get parameter value
     * @param key Parameter key
     * @return Parameter value
     */
    function getParameter(bytes32 key) external view override returns (uint256) {
        return parameters[key];
    }

    /**
     * @notice Get daily revenue for a specific day
     * @param day Day (timestamp / 86400)
     * @return Revenue for that day
     */


    /**
     * @notice Get total fees collected
     * @return Total fees collected
     */
    function getTotalFeesCollected() external view override returns (uint256) {
        return totalFeesCollected;
    }

    // ============ ADMIN FUNCTIONS ============

    /**
     * @notice Update a parameter (DAO only)
     * @param key Parameter key
     * @param value New parameter value
     */
    function updateParameter(bytes32 key, uint256 value) external override onlyDAO {
        uint256 oldValue = parameters[key];
        parameters[key] = value;
        
        emit Events.ParameterUpdated("ReputationRegistry", key, oldValue, value, msg.sender);
    }

    /**
     * @notice Pause the contract (emergency)
     */
    function pause() external {
        require(hasRole(PAUSER_ROLE, msg.sender), "ReputationRegistry: caller cannot pause");
        _pause();
    }

    /**
     * @notice Unpause the contract
     */
    function unpause() external onlyDAO {
        _unpause();
    }

    /**
     * @notice Withdraw collected fees to DAO
     * @param amount Amount to withdraw
     */
    function withdrawFees(uint256 amount) external override onlyDAO {
        require(amount > 0, "ReputationRegistry: invalid amount");
        require(amount <= usdcToken.balanceOf(address(this)), "ReputationRegistry: insufficient balance");

        usdcToken.safeTransfer(msg.sender, amount);
    }
}