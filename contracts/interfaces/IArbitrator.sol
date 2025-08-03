// SPDX-License-Identifier: ISC
pragma solidity ^0.8.20;

/**
 * @title IArbitrator
 * @notice Interface for arbitrators in the dispute resolution system
 * @dev Defines the interface for authorized arbitrators to resolve disputes
 */
interface IArbitrator {
    /// @notice Arbitrator status information
    struct ArbitratorInfo {
        bool authorized;            // Whether arbitrator is authorized
        uint256 stakeRequired;      // Stake required from arbitrator
        uint256 stakeDeposited;     // Actual stake deposited
        uint32 disputesResolved;    // Number of disputes resolved
        uint32 averageResolutionTime; // Average time to resolve disputes
        uint256 registeredAt;       // Registration timestamp
        bool active;               // Active status
    }

    /// @notice Dispute resolution status
    enum ResolutionStatus {
        PENDING,                   // Dispute awaiting resolution
        RESOLVED,                  // Dispute resolved
        APPEALED,                  // Dispute appealed
        FINAL                      // Final resolution (no appeals)
    }

    // Events
    event ArbitratorRegistered(address indexed arbitrator, uint256 stakeRequired);
    event ArbitratorActivated(address indexed arbitrator);
    event ArbitratorDeactivated(address indexed arbitrator);
    event StakeDeposited(address indexed arbitrator, uint256 amount);
    event StakeWithdrawn(address indexed arbitrator, uint256 amount);
    event DisputeAssigned(uint256 indexed disputeId, address indexed arbitrator);
    event DisputeResolved(
        uint256 indexed disputeId,
        address indexed arbitrator,
        bool buyerWins,
        string notes
    );
    event EvidenceSubmitted(uint256 indexed disputeId, address indexed party, string evidence);
    event ResolutionAppealed(uint256 indexed disputeId, address indexed appellant);

    /**
     * @notice Register as an arbitrator with required stake
     * @param stakeAmount The amount of stake to deposit
     */
    function registerArbitrator(uint256 stakeAmount) external;

    /**
     * @notice Deposit additional stake
     * @param amount The amount of additional stake to deposit
     */
    function depositStake(uint256 amount) external;

    /**
     * @notice Withdraw stake (only if not actively arbitrating)
     * @param amount The amount of stake to withdraw
     */
    function withdrawStake(uint256 amount) external;

    /**
     * @notice Accept a dispute assignment
     * @param disputeId The ID of the dispute to accept
     */
    function acceptDispute(uint256 disputeId) external;

    /**
     * @notice Submit evidence for a dispute
     * @param disputeId The ID of the dispute
     * @param evidence The evidence to submit
     */
    function submitEvidence(uint256 disputeId, string calldata evidence) external;

    /**
     * @notice Resolve a dispute
     * @param disputeId The ID of the dispute to resolve
     * @param buyerWins Whether the buyer wins the dispute
     * @param notes Arbitrator's resolution notes
     */
    function resolveDispute(uint256 disputeId, bool buyerWins, string calldata notes) external;

    /**
     * @notice Appeal a dispute resolution
     * @param disputeId The ID of the dispute to appeal
     * @param reason The reason for the appeal
     */
    function appealResolution(uint256 disputeId, string calldata reason) external;

    /**
     * @notice Get arbitrator information
     * @param arbitrator The address of the arbitrator
     * @return ArbitratorInfo struct with arbitrator details
     */
    function getArbitratorInfo(address arbitrator) external view returns (ArbitratorInfo memory);

    /**
     * @notice Check if an address is an authorized arbitrator
     * @param arbitrator The address to check
     * @return True if the address is an authorized arbitrator
     */
    function isAuthorizedArbitrator(address arbitrator) external view returns (bool);

    /**
     * @notice Get the required stake for an arbitrator
     * @param arbitrator The address of the arbitrator
     * @return The required stake amount
     */
    function getRequiredStake(address arbitrator) external view returns (uint256);

    /**
     * @notice Get the deposited stake for an arbitrator
     * @param arbitrator The address of the arbitrator
     * @return The deposited stake amount
     */
    function getDepositedStake(address arbitrator) external view returns (uint256);

    /**
     * @notice Get the number of disputes resolved by an arbitrator
     * @param arbitrator The address of the arbitrator
     * @return The number of disputes resolved
     */
    function getDisputesResolved(address arbitrator) external view returns (uint32);

    /**
     * @notice Get the average resolution time for an arbitrator
     * @param arbitrator The address of the arbitrator
     * @return The average resolution time in seconds
     */
    function getAverageResolutionTime(address arbitrator) external view returns (uint32);

    /**
     * @notice Get the resolution status of a dispute
     * @param disputeId The ID of the dispute
     * @return The resolution status
     */
    function getResolutionStatus(uint256 disputeId) external view returns (ResolutionStatus);

    /**
     * @notice Get the list of active arbitrators
     * @return Array of active arbitrator addresses
     */
    function getActiveArbitrators() external view returns (address[] memory);

    /**
     * @notice Get pending disputes assigned to an arbitrator
     * @param arbitrator The address of the arbitrator
     * @return Array of pending dispute IDs
     */
    function getPendingDisputes(address arbitrator) external view returns (uint256[] memory);
}