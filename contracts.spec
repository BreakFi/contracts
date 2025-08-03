# Smart Contracts Technical Specification

## Overview

This specification defines the implementation of three interconnected smart contracts:
1. **P2P Escrow Contract** - Handles peer-to-peer trading with mutual consent
2. **Reputation Registry Contract** - Manages cross-platform reputation data
3. **Platform DAO Contract** - Controls parameters and collects revenue

## Contract 1: P2P Escrow Contract

### Core Data Structures

```solidity
enum EscrowState {
    NONE,               // 0 - Does not exist
    PROPOSED,           // 1 - Proposal created, waiting for acceptance
    ACCEPTED,           // 2 - Proposal accepted, waiting for funding
    FUNDED,             // 3 - Crypto deposited, ready for fiat transfer
    TO_REFUND_TIMEOUT,  // 4 - Refund requested, timeout period active
    DISPUTED,           // 5 - Dispute raised, awaiting arbitration
    COMPLETED,          // 6 - Transaction completed successfully
    CANCELLED,          // 7 - Escrow cancelled/refunded
    REJECTED            // 8 - Proposal rejected
}

struct Escrow {
    address buyer;              // 160 bits - Buyer address
    address seller;             // 160 bits - Seller address
    address initiator;          // 160 bits - Who created the proposal
    address cryptoToken;        // 160 bits - ERC20 token address
    uint256 cryptoAmount;       // 256 bits - Amount of crypto
    uint256 fiatAmount;         // 256 bits - Amount of fiat (in cents)
    string fiatCurrency;        // Currency code (EUR, USD, etc.)
    uint32 timeoutDuration;     // 32 bits - Timeout in seconds
    uint32 createdAt;          // 32 bits - Creation timestamp
    uint32 fundedAt;           // 32 bits - Funding timestamp
    uint32 expiresAt;          // 32 bits - Expiration timestamp
    EscrowState state;         // 8 bits - Current state
    bool funded;               // 8 bits - Whether crypto is deposited
    uint256 disputeId;         // 256 bits - Reference to dispute (if any)
}

struct Dispute {
    uint256 escrowId;          // 256 bits - Associated escrow
    address initiator;         // 160 bits - Who raised the dispute
    address arbitrator;        // 160 bits - Assigned arbitrator
    uint32 createdAt;         // 32 bits - Dispute creation time
    uint32 evidenceDeadline;  // 32 bits - Evidence submission deadline
    uint32 resolutionDeadline; // 32 bits - Arbitrator response deadline
    bool resolved;            // 8 bits - Whether dispute is resolved
    bool buyerWins;           // 8 bits - Resolution outcome
    string buyerEvidence;     // Buyer's evidence/arguments
    string sellerEvidence;    // Seller's evidence/arguments
    string arbitratorNotes;   // Arbitrator's resolution notes
}
```

### Storage Mappings

```solidity
contract P2PEscrow {
    // Core storage
    mapping(uint256 => Escrow) public escrows;
    mapping(uint256 => Dispute) public disputes;
    mapping(address => bool) public authorizedArbitrators;
    mapping(address => uint256) public arbitratorStakes;
    
    // Counters
    uint256 public escrowCount;
    uint256 public disputeCount;
    
    // Fee and parameter storage
    mapping(bytes32 => uint256) public parameters;
    
    // Revenue tracking
    uint256 public totalFeesCollected;
    uint256 public daoBalance;
    mapping(uint256 => uint256) public dailyRevenue; // day => amount
    
    // Rate limiting and security
    mapping(address => mapping(uint256 => uint256)) public dailyVolume; // user => day => volume
    mapping(address => bool) public kycVerified;
    
    // Supported tokens
    mapping(address => bool) public supportedTokens;
    mapping(address => uint8) public tokenDecimals;
}
```

### Core Functions

#### Proposal Management

```solidity
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
```

#### Escrow Execution

```solidity
function fundEscrow(uint256 escrowId) external;

function completeTransaction(uint256 escrowId) external;

function requestRefund(uint256 escrowId) external;

function executeRefund(uint256 escrowId) external;
```

#### Dispute Management

```solidity
function raiseDispute(uint256 escrowId, string calldata evidence) external returns (uint256 disputeId);

function submitEvidence(uint256 disputeId, string calldata evidence) external;

function resolveDispute(
    uint256 disputeId,
    bool buyerWins,
    string calldata notes
) external onlyArbitrator;

function assignArbitrator(uint256 disputeId, address arbitrator) external;
```

#### Admin Functions

```solidity
function addAuthorizedArbitrator(address arbitrator, uint256 stakeRequired) external onlyDAO;

function removeAuthorizedArbitrator(address arbitrator) external onlyDAO;

function updateParameter(bytes32 key, uint256 value) external onlyDAO;

function addSupportedToken(address token, uint8 decimals) external onlyDAO;

function setKYCStatus(address user, bool verified) external onlyDAO;

function withdrawDAOFunds(uint256 amount) external onlyDAO;
```

### Parameter Keys

```solidity
bytes32 public constant BASE_FEE_PERCENTAGE = keccak256("BASE_FEE_PERCENTAGE");
bytes32 public constant MINIMUM_FEE_USD = keccak256("MINIMUM_FEE_USD");
bytes32 public constant MAXIMUM_FEE_USD = keccak256("MAXIMUM_FEE_USD");
bytes32 public constant DISPUTE_TIME_WINDOW = keccak256("DISPUTE_TIME_WINDOW");
bytes32 public constant ARBITRATION_FEE = keccak256("ARBITRATION_FEE");
bytes32 public constant EVIDENCE_SUBMISSION_TIME = keccak256("EVIDENCE_SUBMISSION_TIME");
bytes32 public constant ARBITRATOR_RESPONSE_TIME = keccak256("ARBITRATOR_RESPONSE_TIME");
bytes32 public constant MAX_ESCROW_AMOUNT = keccak256("MAX_ESCROW_AMOUNT");
bytes32 public constant DAILY_VOLUME_LIMIT = keccak256("DAILY_VOLUME_LIMIT");
bytes32 public constant KYC_REQUIRED_ABOVE = keccak256("KYC_REQUIRED_ABOVE");
```

### Events

```solidity
event ProposalCreated(uint256 indexed escrowId, address indexed initiator, address indexed counterparty);
event ProposalAccepted(uint256 indexed escrowId, address indexed acceptor);
event ProposalRejected(uint256 indexed escrowId, address indexed rejector, string reason);
event EscrowFunded(uint256 indexed escrowId, uint256 amount);
event TransactionCompleted(uint256 indexed escrowId, uint256 feeAmount);
event RefundRequested(uint256 indexed escrowId, address indexed requester);
event RefundExecuted(uint256 indexed escrowId, uint256 amount);
event DisputeRaised(uint256 indexed escrowId, uint256 indexed disputeId, address indexed initiator);
event DisputeResolved(uint256 indexed disputeId, bool buyerWins, address arbitrator);
event ParameterUpdated(bytes32 indexed parameter, uint256 value);
```

## Contract 2: Reputation Registry Contract

### Core Data Structures

```solidity
enum AuthTier {
    NONE,           // 0 - Not authorized
    PREPAID,        // 1 - Pay per submission
    DAO_APPROVED    // 2 - Free unlimited submissions
}

struct ContractInfo {
    AuthTier tier;              // 8 bits - Authorization level
    uint32 weight;              // 32 bits - Reputation weight (0-100)
    uint32 registeredAt;        // 32 bits - Registration timestamp
    uint32 submissionCount;     // 32 bits - Total events submitted
    bool active;                // 8 bits - Active status
    string name;                // Contract/platform name
}

struct UserStatus {
    uint32 statusValue;         // 32 bits - Numeric status/tier
    uint32 updatedAt;          // 32 bits - Last update timestamp
    uint32 expiryDate;         // 32 bits - Status expiry (0 = no expiry)
    bool active;               // 8 bits - Status active flag
}

struct ReputationEvent {
    address subject;            // 160 bits - User being rated
    uint32 timestamp;          // 32 bits - Event timestamp
    uint32 value;              // 32 bits - Rating/score value
    uint32 blockNumber;        // 32 bits - Block number
}
```

### Storage Mappings

```solidity
contract ReputationRegistry {
    // Contract registry
    mapping(address => ContractInfo) public contractRegistry;
    
    // Credit system for prepaid contracts
    mapping(address => uint256) public creditBalances;
    
    // User statuses: contract -> user -> status
    mapping(address => mapping(address => UserStatus)) public userStatuses;
    
    // Reputation events: contract -> subject -> event_type -> events[]
    mapping(address => mapping(address => mapping(bytes32 => ReputationEvent[]))) private reputationEvents;
    
    // Event deduplication
    mapping(bytes32 => bool) public eventExists;
    
    // Parameters
    mapping(bytes32 => uint256) public parameters;
    
    // Revenue tracking
    uint256 public totalFeesCollected;
    uint256 public daoBalance;
    
    // Token reference
    IERC20 public constant USDC = IERC20(0xA0b86a33E6441d5a6C4b0C40A6C8cE9BB1a8C5FA);
}
```

### Event Types (Constants)

```solidity
bytes32 public constant TRADE_COMPLETED = keccak256("trade_completed");
bytes32 public constant DISPUTE_WON = keccak256("dispute_won");
bytes32 public constant DISPUTE_LOST = keccak256("dispute_lost");
bytes32 public constant LOAN_REPAID = keccak256("loan_repaid");
bytes32 public constant SWAP_COMPLETED = keccak256("swap_completed");
bytes32 public constant SERVICE_COMPLETED = keccak256("service_completed");
bytes32 public constant KYC_VERIFIED = keccak256("kyc_verified");
bytes32 public constant IDENTITY_VERIFIED = keccak256("identity_verified");
```

### Core Functions

#### Registration Functions

```solidity
function registerPrepaidContract(
    uint256 initialCredits,
    string calldata name
) external returns (bool);

function approveContract(
    address contractAddress,
    uint32 weight,
    string calldata name
) external onlyDAO;

function revokeContract(address contractAddress) external onlyDAO;

function addCredits(uint256 amount) external;
```

#### Data Submission Functions

```solidity
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
) external onlyDAOApproved;

function updateUserStatus(
    address user,
    uint32 statusValue,
    uint32 expiryDate
) external;

function batchUpdateUserStatuses(
    address[] calldata users,
    uint32[] calldata statusValues,
    uint32[] calldata expiryDates
) external;
```

#### Data Retrieval Functions (All Free)

```solidity
function getReputationEvents(
    address contractAddress,
    address subject,
    bytes32 eventType
) external view returns (ReputationEvent[] memory);

function getEventCount(
    address contractAddress,
    address subject,
    bytes32 eventType
) external view returns (uint256);

function getRecentEvents(
    address contractAddress,
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
) external view returns (
    ReputationEvent[] memory events,
    uint256 total,
    bool hasMore
);

function getContractInfo(address contractAddress) external view returns (ContractInfo memory);

function getUserStatus(address contractAddress, address user) external view returns (UserStatus memory);

function isStatusActive(address contractAddress, address user) external view returns (bool);

function getBatchUserStatuses(
    address contractAddress,
    address[] calldata users
) external view returns (UserStatus[] memory);
```

#### Admin Functions

```solidity
function updateParameter(bytes32 key, uint256 value) external onlyDAO;

function withdrawDAOFunds(uint256 amount) external onlyDAO;

function getDAOBalance() external view returns (uint256);

function getDailyRevenue() external view returns (uint256);
```

### Parameter Keys

```solidity
bytes32 public constant PREPAID_SUBMISSION_FEE = keccak256("PREPAID_SUBMISSION_FEE");
bytes32 public constant REGISTRATION_DEPOSIT = keccak256("REGISTRATION_DEPOSIT");
bytes32 public constant MAX_CONTRACT_WEIGHT = keccak256("MAX_CONTRACT_WEIGHT");
bytes32 public constant DEFAULT_CONTRACT_WEIGHT = keccak256("DEFAULT_CONTRACT_WEIGHT");
bytes32 public constant MAX_BATCH_SIZE = keccak256("MAX_BATCH_SIZE");
bytes32 public constant MIN_SUBMISSION_DELAY = keccak256("MIN_SUBMISSION_DELAY");
bytes32 public constant EVENT_EXPIRY_TIME = keccak256("EVENT_EXPIRY_TIME");
```

### Events

```solidity
event ContractRegistered(address indexed contractAddress, AuthTier tier, string name);
event ContractApproved(address indexed contractAddress, uint32 weight, string name);
event ContractRevoked(address indexed contractAddress);
event CreditsAdded(address indexed contractAddress, uint256 amount);
event ReputationEventSubmitted(address indexed contractAddress, address indexed subject, bytes32 eventType, uint256 value);
event UserStatusUpdated(address indexed contractAddress, address indexed user, uint32 statusValue, uint32 expiryDate);
event ParameterUpdated(bytes32 indexed parameter, uint256 value);
```

## Contract 3: Platform DAO Contract

### Core Data Structures

```solidity
struct Transaction {
    address to;                 // 160 bits - Target address
    uint256 value;             // 256 bits - ETH value
    bytes data;                // Call data
    bool executed;             // 8 bits - Execution status
    mapping(address => bool) signatures; // Signer approvals
    uint256 signatureCount;    // 256 bits - Number of signatures
    uint32 createdAt;         // 32 bits - Creation timestamp
}

struct RevenueData {
    uint256 escrowFees;        // 256 bits - Escrow revenue
    uint256 reputationFees;    // 256 bits - Reputation revenue
    uint256 timestamp;         // 256 bits - Recording timestamp
}
```

### Storage Mappings

```solidity
contract PlatformDAO {
    // Governed contracts
    IP2PEscrow public escrowContract;
    IReputationRegistry public reputationRegistry;
    IERC20 public constant USDC = IERC20(0xA0b86a33E6441d5a6C4b0C40A6C8cE9BB1a8C5FA);
    
    // Multi-sig configuration
    address[] public signers;
    uint256 public requiredSignatures;
    mapping(address => bool) public isSigner;
    
    // Transaction management
    mapping(uint256 => Transaction) public transactions;
    uint256 public transactionCount;
    
    // Parameter management
    mapping(bytes32 => uint256) public parameters;
    mapping(bytes32 => bool) public parameterExists;
    
    // Revenue tracking
    uint256 public totalRevenueCollected;
    uint256 public lastCollectionTimestamp;
    RevenueData[] public dailyRevenue;
    mapping(uint256 => uint256) public monthlyTotals; // month_key => total
}
```

### Core Functions

#### Multi-Sig Management

```solidity
function submitTransaction(
    address to,
    uint256 value,
    bytes calldata data
) external onlySigner returns (uint256 txId);

function signTransaction(uint256 txId) external onlySigner;

function executeTransaction(uint256 txId) external;

function revokeSignature(uint256 txId) external onlySigner;

function addSigner(address newSigner) external onlyDAO;

function removeSigner(address signer) external onlyDAO;

function changeRequiredSignatures(uint256 newRequired) external onlyDAO;
```

#### Revenue Collection

```solidity
function collectEscrowRevenue() external returns (uint256 collected);

function collectReputationRevenue() external returns (uint256 collected);

function collectAllRevenue() external returns (uint256 totalCollected);

function withdrawFunds(
    address recipient,
    uint256 amount,
    string calldata purpose
) external onlyDAO;

function emergencyWithdraw(address recipient) external onlyDAO;

function getTreasuryBalance() external view returns (uint256);
```

#### Parameter Management

```solidity
function setEscrowParameter(bytes32 parameterKey, uint256 value) external onlyDAO;

function setReputationParameter(bytes32 parameterKey, uint256 value) external onlyDAO;

function batchUpdateEscrowParameters(
    bytes32[] calldata keys,
    uint256[] calldata values
) external onlyDAO;

function batchUpdateReputationParameters(
    bytes32[] calldata keys,
    uint256[] calldata values
) external onlyDAO;
```

#### Contract Management

```solidity
function addArbitrator(address arbitrator, uint256 stakeRequired) external onlyDAO;

function removeArbitrator(address arbitrator) external onlyDAO;

function approveReputationContract(
    address contractAddress,
    uint32 weight,
    string calldata name
) external onlyDAO;

function revokeReputationContract(address contractAddress) external onlyDAO;
```

#### Revenue Analytics

```solidity
function recordDailyRevenue() external;

function getMonthlyRevenue(uint256 month, uint256 year) external view returns (uint256);

function getTotalRevenue() external view returns (uint256);

function getDailyRevenueHistory(uint256 days) external view returns (RevenueData[] memory);
```

### Direct Parameter Functions

```solidity
function setEscrowFee(uint256 newFeePercentage) external onlyDAO;
function setDisputeTimeout(uint256 newTimeoutSeconds) external onlyDAO;
function setReputationSubmissionFee(uint256 newFeeUSDC) external onlyDAO;
function setMaxEscrowAmount(uint256 newMaxAmount) external onlyDAO;
function setArbitrationFee(uint256 newFeeUSDC) external onlyDAO;
function setKYCThreshold(uint256 newThresholdUSDC) external onlyDAO;
```

### Events

```solidity
event TransactionSubmitted(uint256 indexed txId, address indexed submitter, address to, uint256 value);
event TransactionSigned(uint256 indexed txId, address indexed signer);
event TransactionExecuted(uint256 indexed txId);
event SignatureRevoked(uint256 indexed txId, address indexed signer);
event SignerAdded(address indexed signer);
event SignerRemoved(address indexed signer);
event RequiredSignaturesChanged(uint256 oldRequired, uint256 newRequired);
event ParameterUpdated(string indexed contractType, bytes32 indexed parameter, uint256 value);
event RevenueCollected(address indexed source, uint256 amount, uint256 timestamp);
event RevenueWithdrawn(address indexed recipient, uint256 amount, string purpose);
event ArbitratorAdded(address indexed arbitrator, uint256 stakeRequired);
event ArbitratorRemoved(address indexed arbitrator);
event ContractApproved(address indexed contractAddress, uint32 weight, string name);
event ContractRevoked(address indexed contractAddress);
event DailyRevenueRecorded(uint256 escrowFees, uint256 reputationFees, uint256 timestamp);
```

## Implementation Requirements

### Dependencies

```solidity
// Required imports for all contracts
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Context.sol";
```

### Security Considerations

1. **Reentrancy Protection**: All state-changing functions must use ReentrancyGuard
2. **Access Control**: Proper role-based access control for admin functions
3. **Parameter Validation**: All parameter updates must validate ranges
4. **Integer Overflow**: Use SafeMath or Solidity 0.8+ built-in checks
5. **Token Transfer Safety**: Use SafeERC20 for all token interactions
6. **Pause Mechanism**: Emergency pause functionality for all contracts
7. **Event Emission**: Comprehensive event logging for off-chain monitoring

### Gas Optimization

1. **Packed Structs**: Optimize struct layouts to minimize storage slots
2. **Batch Operations**: Implement batch functions for multiple operations
3. **View Functions**: Use view/pure modifiers where possible
4. **Memory vs Storage**: Optimize memory usage in functions
5. **Loop Limits**: Implement reasonable limits on array operations

### Default Parameter Values

#### Escrow Contract Defaults
```solidity
BASE_FEE_PERCENTAGE = 100;          // 1.0%
MINIMUM_FEE_USD = 500000;           // $0.50 (6 decimals)
MAXIMUM_FEE_USD = 500000000;        // $500 (6 decimals)
DISPUTE_TIME_WINDOW = 259200;       // 72 hours
ARBITRATION_FEE = 25000000;         // $25 (6 decimals)
EVIDENCE_SUBMISSION_TIME = 172800;  // 48 hours
ARBITRATOR_RESPONSE_TIME = 604800;  // 7 days
MAX_ESCROW_AMOUNT = 100000000000;   // $100,000 (6 decimals)
DAILY_VOLUME_LIMIT = 1000000000000; // $1,000,000 (6 decimals)
KYC_REQUIRED_ABOVE = 10000000000;   // $10,000 (6 decimals)
```

#### Reputation Registry Defaults
```solidity
PREPAID_SUBMISSION_FEE = 1000000;   // $1.00 (6 decimals)
REGISTRATION_DEPOSIT = 100000000;   // $100 (6 decimals)
MAX_CONTRACT_WEIGHT = 100;          // Maximum weight
DEFAULT_CONTRACT_WEIGHT = 50;       // Default weight
MAX_BATCH_SIZE = 100;               // 100 events per batch
MIN_SUBMISSION_DELAY = 60;          // 1 minute
EVENT_EXPIRY_TIME = 63072000;       // 2 years
```

### Testing Requirements

1. **Unit Tests**: 100% coverage for all public functions
2. **Integration Tests**: End-to-end workflow testing
3. **Stress Tests**: High-volume transaction testing
4. **Security Tests**: Attack vector testing
5. **Gas Tests**: Gas consumption optimization testing

### Deployment Checklist

1. **Contract Verification**: Verify source code on block explorers
2. **Parameter Initialization**: Set all default parameters
3. **Role Assignment**: Assign initial admin roles
4. **Token Whitelisting**: Add supported tokens to escrow
5. **DAO Configuration**: Set initial signers and thresholds
6. **Integration Testing**: Test contract interactions
7. **Monitoring Setup**: Deploy event monitoring infrastructure

This specification provides the complete technical foundation for implementing the three-contract system with proper security, efficiency, and functionality as described in the source documents.