// SPDX-License-Identifier: ISC
pragma solidity ^0.8.20;

/**
 * @title IReputationRegistry
 * @notice Interface for the Reputation Registry contract
 * @dev Manages cross-platform reputation data with two-tier authorization
 */
interface IReputationRegistry {
    /// @notice Authorization tiers for contracts
    enum AuthTier {
        NONE,           // Not authorized
        PREPAID,        // Pay per submission
        DAO_APPROVED    // Free unlimited submissions
    }

    /// @notice Contract registration information
    struct ContractInfo {
        AuthTier tier;          // Authorization level
        uint32 weight;          // Reputation weight (0-100)
        uint32 registeredAt;    // Registration timestamp
        uint32 submissionCount; // Total events submitted
        bool active;            // Active status
        string name;            // Contract/platform name
    }

    /// @notice User status information (contract-specific)
    struct UserStatus {
        uint32 statusValue;     // Numeric status/tier
        uint32 updatedAt;       // Last update timestamp
        uint32 expiryDate;      // Status expiry (0 = no expiry)
        bool active;            // Status active flag
    }

    /// @notice Reputation event data structure
    struct ReputationEvent {
        address subject;        // User being rated
        uint32 timestamp;       // Event timestamp
        uint32 value;          // Rating/score value
        uint32 blockNumber;    // Block number
    }

    // Events
    event ContractRegistered(address indexed contractAddr, AuthTier tier, uint32 weight, string name);
    event ContractApproved(address indexed contractAddr, uint32 weight, string name);
    event ContractRevoked(address indexed contractAddr, string reason);
    event CreditsAdded(address indexed contractAddr, uint256 amount, uint256 newBalance);
    event CreditsDeducted(address indexed contractAddr, uint256 amount, uint256 newBalance);
    event ReputationEventSubmitted(address indexed contractAddr, address indexed subject, bytes32 indexed eventType, uint256 value);
    event UserStatusUpdated(address indexed contractAddr, address indexed user, uint32 statusValue, uint32 expiryDate);
    event ParameterUpdated(bytes32 indexed parameter, uint256 oldValue, uint256 newValue);

    // Registration Functions
    function registerPrepaidContract(uint256 initialCredits, string calldata name) external;
    function approveContract(address contractAddr, uint32 weight, string calldata name) external;
    function revokeContract(address contractAddr, string calldata reason) external;
    function addCredits(uint256 amount) external;

    // Data Submission Functions
    function submitReputationEvent(
        address subject,
        bytes32 eventType,
        uint256 value,
        bytes32 eventId,
        bytes calldata metadata
    ) external;

    function batchSubmitEvents(
        address[] calldata subjects,
        bytes32[] calldata eventTypes,
        uint256[] calldata values,
        bytes32[] calldata eventIds
    ) external;

    function updateUserStatus(address user, uint32 statusValue, uint32 expiryDate) external;

    function batchUpdateUserStatuses(
        address[] calldata users,
        uint32[] calldata statusValues,
        uint32[] calldata expiryDates
    ) external;

    // Data Retrieval Functions (All Free)
    function getReputationEvents(
        address contractAddr,
        address subject,
        bytes32 eventType
    ) external view returns (ReputationEvent[] memory);

    function getEventCount(
        address contractAddr,
        address subject,
        bytes32 eventType
    ) external view returns (uint256);

    function getRecentEvents(
        address contractAddr,
        address subject,
        bytes32 eventType,
        uint256 limit
    ) external view returns (ReputationEvent[] memory);

    function getEventsPaginated(
        address contractAddr,
        address subject,
        bytes32 eventType,
        uint256 offset,
        uint256 limit
    ) external view returns (ReputationEvent[] memory events, uint256 total, bool hasMore);

    function getContractInfo(address contractAddr) external view returns (ContractInfo memory);

    function getUserStatus(address contractAddr, address user) external view returns (UserStatus memory);

    function isStatusActive(address contractAddr, address user) external view returns (bool);

    function getBatchUserStatuses(
        address contractAddr,
        address[] calldata users
    ) external view returns (UserStatus[] memory);

    // Admin Functions
    function updateParameter(bytes32 key, uint256 value) external;
    function withdrawFees(uint256 amount) external;

    // Additional View Functions
    function isContractRegistered(address contractAddr) external view returns (bool);
    function getCreditBalance(address contractAddr) external view returns (uint256);
    function getParameter(bytes32 key) external view returns (uint256);

    function getTotalFeesCollected() external view returns (uint256);

    // Note: Public storage getters are automatically generated by Solidity
    // contractRegistry(address) -> ContractInfo
    // creditBalances(address) -> uint256  
    // userStatuses(address, address) -> UserStatus
    // eventExists(bytes32) -> bool
    // parameters(bytes32) -> uint256
}