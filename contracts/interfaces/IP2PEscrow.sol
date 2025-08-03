// SPDX-License-Identifier: ISC
pragma solidity ^0.8.20;

/**
 * @title IP2PEscrow
 * @notice Interface for the P2P Escrow contract
 * @dev Handles peer-to-peer trading with mutual consent and bidirectional proposals
 */
interface IP2PEscrow {
    /// @notice Escrow states
    enum EscrowState {
        NONE,               // Does not exist
        PROPOSED,           // Proposal created, waiting for acceptance
        ACCEPTED,           // Proposal accepted, waiting for funding
        FUNDED,             // Crypto deposited, ready for fiat transfer
        TO_REFUND_TIMEOUT,  // Refund requested, timeout period active
        DISPUTED,           // Dispute raised, awaiting arbitration
        COMPLETED,          // Transaction completed successfully
        CANCELLED,          // Escrow cancelled/refunded
        REJECTED            // Proposal rejected
    }

    /// @notice Main escrow data structure
    struct Escrow {
        address buyer;              // Buyer address
        address seller;             // Seller address
        address initiator;          // Who created the proposal
        address cryptoToken;        // ERC20 token address
        uint256 cryptoAmount;       // Amount of crypto
        uint256 fiatAmount;         // Amount of fiat (in cents)
        string fiatCurrency;        // Currency code (EUR, USD, etc.)
        uint32 timeoutDuration;     // Timeout in seconds
        uint32 createdAt;          // Creation timestamp
        uint32 fundedAt;           // Funding timestamp
        uint32 expiresAt;          // Expiration timestamp
        EscrowState state;         // Current state
        bool funded;               // Whether crypto is deposited
        uint256 disputeId;         // Reference to dispute (if any)
    }

    /// @notice Dispute data structure
    struct Dispute {
        uint256 escrowId;          // Associated escrow
        address initiator;         // Who raised the dispute
        address arbitrator;        // Assigned arbitrator
        uint32 createdAt;         // Dispute creation time
        uint32 evidenceDeadline;  // Evidence submission deadline
        uint32 resolutionDeadline; // Arbitrator response deadline
        bool resolved;            // Whether dispute is resolved
        bool buyerWins;           // Resolution outcome
        string buyerEvidence;     // Buyer's evidence/arguments
        string sellerEvidence;    // Seller's evidence/arguments
        string arbitratorNotes;   // Arbitrator's resolution notes
    }

    // Events
    event ProposalCreated(uint256 indexed escrowId, address indexed initiator, address indexed counterparty);
    event ProposalAccepted(uint256 indexed escrowId, address indexed acceptor, bool withFunding);
    event ProposalRejected(uint256 indexed escrowId, address indexed rejector, string reason);
    event ProposalCancelled(uint256 indexed escrowId, address indexed canceller, string reason);
    event EscrowFunded(uint256 indexed escrowId, address indexed funder, uint256 amount, address token);
    event TransactionCompleted(uint256 indexed escrowId, uint256 feeAmount);
    event RefundRequested(uint256 indexed escrowId, address indexed requester);
    event RefundExecuted(uint256 indexed escrowId, address indexed recipient, uint256 amount);
    event DisputeRaised(uint256 indexed escrowId, uint256 indexed disputeId, address indexed initiator);
    event EvidenceSubmitted(uint256 indexed disputeId, address indexed submitter, string evidence);
    event DisputeResolved(uint256 indexed disputeId, bool buyerWins, address arbitrator);
    event ArbitratorAssigned(uint256 indexed disputeId, address indexed arbitrator);
    event ParameterUpdated(bytes32 indexed parameter, uint256 value);

    // Proposal Management Functions
    function createProposal(
        address counterparty,
        address cryptoToken,
        uint256 cryptoAmount,
        uint256 fiatAmount,
        string calldata fiatCurrency,
        uint32 timeoutDuration
    ) external payable returns (uint256 escrowId);

    function createProposalWithFunding(
        address counterparty,
        address cryptoToken,
        uint256 cryptoAmount,
        uint256 fiatAmount,
        string calldata fiatCurrency,
        uint32 timeoutDuration
    ) external returns (uint256 escrowId);

    function acceptProposal(uint256 escrowId) external;
    function acceptProposalWithFunding(uint256 escrowId) external;
    function rejectProposal(uint256 escrowId, string calldata reason) external;
    function cancelProposal(uint256 escrowId, string calldata reason) external;

    // Escrow Execution Functions
    function fundEscrow(uint256 escrowId) external;
    function completeTransaction(uint256 escrowId) external;
    function requestRefund(uint256 escrowId) external;
    function executeRefund(uint256 escrowId) external;

    // Dispute Management Functions
    function raiseDispute(uint256 escrowId, string calldata evidence) external returns (uint256 disputeId);
    function submitEvidence(uint256 disputeId, string calldata evidence) external;
    function resolveDispute(uint256 disputeId, bool buyerWins, string calldata notes) external;
    function assignArbitrator(uint256 disputeId, address arbitrator) external;

    // Admin Functions
    function addAuthorizedArbitrator(address arbitrator, uint256 stakeRequired) external;
    function removeAuthorizedArbitrator(address arbitrator) external;
    function updateParameter(bytes32 key, uint256 value) external;
    function addSupportedToken(address token, uint8 decimals) external;

    function withdrawDAOFunds(uint256 amount, address token) external;
    function getParameter(bytes32 key) external view returns (uint256);
    function isTokenSupported(address token) external view returns (bool);

    // View Functions - Struct Getters
    function getEscrow(uint256 escrowId) external view returns (Escrow memory);
    function getDispute(uint256 disputeId) external view returns (Dispute memory);
    function authorizedArbitrators(address arbitrator) external view returns (bool);
    function arbitratorStakes(address arbitrator) external view returns (uint256);
    function escrowCount() external view returns (uint256);
    function disputeCount() external view returns (uint256);
    function parameters(bytes32 key) external view returns (uint256);
    function totalFeesCollected() external view returns (uint256);
    function daoBalance() external view returns (uint256);


    function supportedTokens(address token) external view returns (bool);
    function tokenDecimals(address token) external view returns (uint8);
    function getDAOBalance() external view returns (uint256);
}