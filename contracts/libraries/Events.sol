// SPDX-License-Identifier: ISC
pragma solidity ^0.8.20;

/**
 * @title Events
 * @notice Library containing event definitions for all contracts
 * @dev Centralizes event definitions to ensure consistency across contracts
 */
library Events {
    // ============ P2P ESCROW EVENTS ============
    
    /// @notice Emitted when a new proposal is created
    event ProposalCreated(
        uint256 indexed escrowId,
        address indexed initiator,
        address indexed counterparty,
        address cryptoToken,
        uint256 cryptoAmount,
        uint256 fiatAmount,
        string fiatCurrency
    );
    
    /// @notice Emitted when a proposal is accepted
    event ProposalAccepted(
        uint256 indexed escrowId,
        address indexed acceptor,
        bool withFunding
    );
    
    /// @notice Emitted when a proposal is rejected
    event ProposalRejected(
        uint256 indexed escrowId,
        address indexed rejector,
        string reason
    );
    
    /// @notice Emitted when a proposal is cancelled
    event ProposalCancelled(
        uint256 indexed escrowId,
        address indexed canceller,
        string reason
    );
    
    /// @notice Emitted when an escrow is funded
    event EscrowFunded(
        uint256 indexed escrowId,
        address indexed funder,
        uint256 amount,
        address token
    );
    
    /// @notice Emitted when a transaction is completed
    event TransactionCompleted(
        uint256 indexed escrowId,
        address indexed buyer,
        address indexed seller,
        uint256 amount,
        uint256 feeAmount
    );
    
    /// @notice Emitted when a refund is requested
    event RefundRequested(
        uint256 indexed escrowId,
        address indexed requester,
        uint32 timeoutEndsAt
    );
    
    /// @notice Emitted when a refund is executed
    event RefundExecuted(
        uint256 indexed escrowId,
        address indexed recipient,
        uint256 amount
    );
    
    /// @notice Emitted when a dispute is raised
    event DisputeRaised(
        uint256 indexed escrowId,
        uint256 indexed disputeId,
        address indexed initiator,
        string evidence
    );
    
    /// @notice Emitted when evidence is submitted for a dispute
    event EvidenceSubmitted(
        uint256 indexed disputeId,
        address indexed submitter,
        string evidence
    );
    
    /// @notice Emitted when a dispute is resolved
    event DisputeResolved(
        uint256 indexed disputeId,
        uint256 indexed escrowId,
        address indexed arbitrator,
        bool buyerWins,
        uint256 amount
    );
    
    /// @notice Emitted when an arbitrator is assigned to a dispute
    event ArbitratorAssigned(
        uint256 indexed disputeId,
        address indexed arbitrator
    );
    
    // ============ REPUTATION REGISTRY EVENTS ============
    
    /// @notice Emitted when a contract is registered as prepaid
    event ContractRegistered(
        address indexed contractAddress,
        uint8 tier, // AuthTier enum value
        string name,
        uint256 initialCredits
    );
    
    /// @notice Emitted when a contract is approved by DAO
    event ContractApproved(
        address indexed contractAddress,
        uint32 weight,
        string name
    );
    
    /// @notice Emitted when a contract is revoked
    event ContractRevoked(
        address indexed contractAddress,
        string reason
    );
    
    /// @notice Emitted when credits are added to a contract
    event CreditsAdded(
        address indexed contractAddress,
        uint256 amount,
        uint256 newBalance
    );
    
    /// @notice Emitted when credits are deducted from a contract
    event CreditsDeducted(
        address indexed contractAddress,
        uint256 amount,
        uint256 newBalance
    );
    
    /// @notice Emitted when a reputation event is submitted
    event ReputationEventSubmitted(
        address indexed contractAddress,
        address indexed subject,
        bytes32 indexed eventType,
        uint256 value,
        bytes32 eventId
    );
    
    /// @notice Emitted when reputation events are batch submitted
    event ReputationEventsBatchSubmitted(
        address indexed contractAddress,
        uint256 eventCount,
        uint256 totalFee
    );
    
    /// @notice Emitted when a user status is updated
    event UserStatusUpdated(
        address indexed contractAddress,
        address indexed user,
        uint32 statusValue,
        uint32 expiryDate,
        bool active
    );
    
    /// @notice Emitted when user statuses are batch updated
    event UserStatusesBatchUpdated(
        address indexed contractAddress,
        uint256 userCount,
        uint256 totalFee
    );
    
    // ============ PLATFORM DAO EVENTS ============
    
    /// @notice Emitted when a multi-sig transaction is submitted
    event TransactionSubmitted(
        uint256 indexed txId,
        address indexed submitter,
        address indexed to,
        uint256 value,
        bytes data
    );
    
    /// @notice Emitted when a multi-sig transaction is signed
    event TransactionSigned(
        uint256 indexed txId,
        address indexed signer,
        uint256 signatureCount
    );
    
    /// @notice Emitted when a multi-sig transaction is executed
    event TransactionExecuted(
        uint256 indexed txId,
        address indexed executor,
        bool success
    );
    
    /// @notice Emitted when a signature is revoked
    event SignatureRevoked(
        uint256 indexed txId,
        address indexed signer,
        uint256 signatureCount
    );
    
    /// @notice Emitted when a signer is added
    event SignerAdded(
        address indexed signer,
        uint256 newSignerCount
    );
    
    /// @notice Emitted when a signer is removed
    event SignerRemoved(
        address indexed signer,
        uint256 newSignerCount
    );
    
    /// @notice Emitted when required signatures threshold is changed
    event RequiredSignaturesChanged(
        uint256 oldRequired,
        uint256 newRequired
    );
    
    /// @notice Emitted when revenue is collected from a contract
    event RevenueCollected(
        address indexed source,
        uint256 amount,
        uint256 timestamp,
        string contractType
    );
    
    /// @notice Emitted when funds are withdrawn from treasury
    event RevenueWithdrawn(
        address indexed recipient,
        uint256 amount,
        string purpose,
        address indexed approver
    );
    
    /// @notice Emitted when an arbitrator is added
    event ArbitratorAdded(
        address indexed arbitrator,
        uint256 stakeRequired,
        address indexed addedBy
    );
    
    /// @notice Emitted when an arbitrator is removed
    event ArbitratorRemoved(
        address indexed arbitrator,
        address indexed removedBy,
        string reason
    );
    
    /// @notice Emitted when daily revenue is recorded
    event DailyRevenueRecorded(
        uint256 indexed day,
        uint256 escrowFees,
        uint256 reputationFees,
        uint256 totalRevenue
    );
    
    // ============ SHARED EVENTS ============
    
    /// @notice Emitted when a parameter is updated
    event ParameterUpdated(
        string indexed contractType,
        bytes32 indexed parameter,
        uint256 oldValue,
        uint256 newValue,
        address indexed updatedBy
    );
    
    /// @notice Emitted when contract is paused
    event ContractPaused(
        address indexed contract_,
        address indexed pausedBy,
        string reason
    );
    
    /// @notice Emitted when contract is unpaused
    event ContractUnpaused(
        address indexed contract_,
        address indexed unpausedBy
    );
    
    /// @notice Emitted when emergency action is taken
    event EmergencyAction(
        string indexed actionType,
        address indexed initiator,
        string details,
        uint256 timestamp
    );
    
    /// @notice Emitted when a supported token is added
    event SupportedTokenAdded(
        address indexed token,
        string symbol,
        uint8 decimals
    );
    
    /// @notice Emitted when a supported token is removed
    event SupportedTokenRemoved(
        address indexed token,
        string reason
    );

    /// @notice Emitted when KYC status is updated
    event KYCStatusUpdated(
        address indexed user,
        bool verified,
        address indexed updatedBy,
        string verificationLevel
    );
    
    /// @notice Emitted when a supported token is added
    event SupportedTokenAdded(
        address indexed token,
        string symbol,
        uint8 decimals,
        address indexed addedBy
    );
    
    /// @notice Emitted when a supported token is removed
    event SupportedTokenRemoved(
        address indexed token,
        address indexed removedBy,
        string reason
    );
}