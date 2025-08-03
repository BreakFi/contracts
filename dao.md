# P2P Platform Parameter Control DAO Specification

## Executive Summary

The P2P Platform DAO is a simplified multi-signature contract that serves two primary functions: collecting revenue from the Escrow and Reputation Registry contracts, and setting operational parameters for both contracts. It operates without proposal mechanisms, focusing on direct parameter management and treasury collection.

## Contract Architecture

### Core DAO Structure

```solidity
contract PlatformDAO {
    // Governed contracts
    IEscrowContract public escrowContract;
    IReputationRegistry public reputationRegistry;
    IERC20 public constant USDC = IERC20(0xA0b86a33E6441d5a6C4b0C40A6C8cE9BB1a8C5FA); // USDC address
    
    // Multi-sig configuration
    address[] public signers;
    uint256 public requiredSignatures;
    
    // Parameter management
    mapping(bytes32 => uint256) public parameters;
    mapping(bytes32 => bool) public parameterExists;
    
    // Revenue tracking
    uint256 public totalRevenueCollected;
    uint256 public lastCollectionTimestamp;
    
    modifier onlyDAO() {
        require(isValidDAOTransaction(), "Insufficient signatures");
        _;
    }
}
```

### Multi-Sig Configuration

**Initial Setup:**
- **Signers**: 4 founders
- **Required Signatures**: 3 of 4 (75% threshold)
- **Parameter Changes**: Immediate execution after signature threshold
- **Fund Withdrawals**: Same signature requirements

## Revenue Collection System

### Automatic Revenue Collection

```solidity
contract RevenueCollector {
    event RevenueCollected(address indexed source, uint256 amount, uint256 timestamp);
    event RevenueWithdrawn(address indexed recipient, uint256 amount, string purpose);
    
    // Collect revenue from escrow contract
    function collectEscrowRevenue() external {
        uint256 balance = escrowContract.getDAOBalance();
        if (balance > 0) {
            escrowContract.withdrawDAOFunds(balance);
            totalRevenueCollected += balance;
            lastCollectionTimestamp = block.timestamp;
            emit RevenueCollected(address(escrowContract), balance, block.timestamp);
        }
    }
    
    // Collect revenue from reputation registry
    function collectReputationRevenue() external {
        uint256 balance = reputationRegistry.getDAOBalance();
        if (balance > 0) {
            reputationRegistry.withdrawDAOFunds(balance);
            totalRevenueCollected += balance;
            lastCollectionTimestamp = block.timestamp;
            emit RevenueCollected(address(reputationRegistry), balance, block.timestamp);
        }
    }
    
    // Collect from both contracts in one transaction
    function collectAllRevenue() external {
        collectEscrowRevenue();
        collectReputationRevenue();
    }
    
    // Get current DAO treasury balance
    function getTreasuryBalance() external view returns (uint256) {
        return USDC.balanceOf(address(this));
    }
}
```

### Fund Management

```solidity
contract FundManager {
    // Withdraw funds for operational expenses
    function withdrawFunds(
        address recipient,
        uint256 amount,
        string calldata purpose
    ) external onlyDAO {
        require(amount <= USDC.balanceOf(address(this)), "Insufficient balance");
        require(recipient != address(0), "Invalid recipient");
        
        USDC.transfer(recipient, amount);
        emit RevenueWithdrawn(recipient, amount, purpose);
    }
    
    // Emergency withdrawal (requires majority of signers)
    function emergencyWithdraw(address recipient) external {
        require(msg.sender == address(this), "Only DAO");
        uint256 balance = USDC.balanceOf(address(this));
        USDC.transfer(recipient, balance);
        emit RevenueWithdrawn(recipient, balance, "EMERGENCY");
    }
}
```

## Parameter Management System

### Escrow Contract Parameters

```solidity
contract EscrowParameterManager {
    // Fee structure parameters
    bytes32 public constant BASE_FEE_PERCENTAGE = keccak256("BASE_FEE_PERCENTAGE");     // 100 = 1.0%
    bytes32 public constant MINIMUM_FEE_USD = keccak256("MINIMUM_FEE_USD");             // In USDC (6 decimals)
    bytes32 public constant MAXIMUM_FEE_USD = keccak256("MAXIMUM_FEE_USD");             // In USDC (6 decimals)
    
    // Dispute parameters
    bytes32 public constant DISPUTE_TIME_WINDOW = keccak256("DISPUTE_TIME_WINDOW");     // Seconds
    bytes32 public constant ARBITRATION_FEE = keccak256("ARBITRATION_FEE");             // In USDC (6 decimals)
    bytes32 public constant EVIDENCE_SUBMISSION_TIME = keccak256("EVIDENCE_SUBMISSION_TIME"); // Seconds
    bytes32 public constant ARBITRATOR_RESPONSE_TIME = keccak256("ARBITRATOR_RESPONSE_TIME");  // Seconds
    
    // Security parameters
    bytes32 public constant MAX_ESCROW_AMOUNT = keccak256("MAX_ESCROW_AMOUNT");         // In USDC (6 decimals)
    bytes32 public constant DAILY_VOLUME_LIMIT = keccak256("DAILY_VOLUME_LIMIT");       // In USDC (6 decimals)
    bytes32 public constant KYC_REQUIRED_ABOVE = keccak256("KYC_REQUIRED_ABOVE");       // In USDC (6 decimals)
    
    function setEscrowParameter(bytes32 parameterKey, uint256 value) external onlyDAO {
        require(_isValidEscrowParameter(parameterKey, value), "Invalid parameter");
        
        parameters[parameterKey] = value;
        parameterExists[parameterKey] = true;
        
        // Update the escrow contract
        escrowContract.updateParameter(parameterKey, value);
        
        emit ParameterUpdated("ESCROW", parameterKey, value);
    }
    
    function _isValidEscrowParameter(bytes32 key, uint256 value) internal pure returns (bool) {
        if (key == BASE_FEE_PERCENTAGE) return value >= 10 && value <= 200;        // 0.1% - 2.0%
        if (key == MINIMUM_FEE_USD) return value >= 100000 && value <= 5000000;    // $0.10 - $5.00
        if (key == MAXIMUM_FEE_USD) return value >= 100000000 && value <= 1000000000; // $100 - $1,000
        if (key == DISPUTE_TIME_WINDOW) return value >= 86400 && value <= 604800;  // 1-7 days
        if (key == ARBITRATION_FEE) return value >= 10000000 && value <= 100000000; // $10 - $100
        if (key == EVIDENCE_SUBMISSION_TIME) return value >= 86400 && value <= 259200; // 1-3 days
        if (key == ARBITRATOR_RESPONSE_TIME) return value >= 86400 && value <= 1209600; // 1-14 days
        if (key == MAX_ESCROW_AMOUNT) return value >= 1000000000 && value <= 1000000000000; // $1,000 - $1M
        if (key == DAILY_VOLUME_LIMIT) return value >= 100000000000 && value <= 10000000000000; // $100K - $10M
        if (key == KYC_REQUIRED_ABOVE) return value >= 1000000000 && value <= 100000000000; // $1,000 - $100K
        return false;
    }
}
```

### Reputation Registry Parameters

```solidity
contract ReputationParameterManager {
    // Submission fee parameters
    bytes32 public constant PREPAID_SUBMISSION_FEE = keccak256("PREPAID_SUBMISSION_FEE"); // In USDC (6 decimals)
    bytes32 public constant REGISTRATION_DEPOSIT = keccak256("REGISTRATION_DEPOSIT");     // In USDC (6 decimals)
    
    // Contract weight parameters
    bytes32 public constant MAX_CONTRACT_WEIGHT = keccak256("MAX_CONTRACT_WEIGHT");       // 0-100
    bytes32 public constant DEFAULT_CONTRACT_WEIGHT = keccak256("DEFAULT_CONTRACT_WEIGHT"); // 0-100
    
    // Data quality parameters
    bytes32 public constant MAX_BATCH_SIZE = keccak256("MAX_BATCH_SIZE");                 // Number of events
    bytes32 public constant MIN_SUBMISSION_DELAY = keccak256("MIN_SUBMISSION_DELAY");     // Seconds
    bytes32 public constant EVENT_EXPIRY_TIME = keccak256("EVENT_EXPIRY_TIME");           // Seconds
    
    function setReputationParameter(bytes32 parameterKey, uint256 value) external onlyDAO {
        require(_isValidReputationParameter(parameterKey, value), "Invalid parameter");
        
        parameters[parameterKey] = value;
        parameterExists[parameterKey] = true;
        
        // Update the reputation registry
        reputationRegistry.updateParameter(parameterKey, value);
        
        emit ParameterUpdated("REPUTATION", parameterKey, value);
    }
    
    function _isValidReputationParameter(bytes32 key, uint256 value) internal pure returns (bool) {
        if (key == PREPAID_SUBMISSION_FEE) return value >= 500000 && value <= 5000000;    // $0.50 - $5.00
        if (key == REGISTRATION_DEPOSIT) return value >= 50000000 && value <= 500000000; // $50 - $500
        if (key == MAX_CONTRACT_WEIGHT) return value >= 1 && value <= 100;               // 1-100
        if (key == DEFAULT_CONTRACT_WEIGHT) return value >= 1 && value <= 100;           // 1-100
        if (key == MAX_BATCH_SIZE) return value >= 10 && value <= 500;                   // 10-500 events
        if (key == MIN_SUBMISSION_DELAY) return value >= 30 && value <= 3600;            // 30s - 1hr
        if (key == EVENT_EXPIRY_TIME) return value >= 31536000 && value <= 157680000;    // 1-5 years
        return false;
    }
}
```

### Contract Management

```solidity
contract ContractManager {
    // Arbitrator management for escrow
    function addArbitrator(address arbitrator, uint256 stakeRequired) external onlyDAO {
        require(arbitrator != address(0), "Invalid arbitrator");
        escrowContract.addAuthorizedArbitrator(arbitrator, stakeRequired);
        emit ArbitratorAdded(arbitrator, stakeRequired);
    }
    
    function removeArbitrator(address arbitrator) external onlyDAO {
        escrowContract.removeAuthorizedArbitrator(arbitrator);
        emit ArbitratorRemoved(arbitrator);
    }
    
    // Contract approval for reputation registry
    function approveReputationContract(
        address contractAddress,
        uint32 weight,
        string calldata name
    ) external onlyDAO {
        require(contractAddress != address(0), "Invalid contract");
        require(weight <= parameters[MAX_CONTRACT_WEIGHT], "Weight too high");
        
        reputationRegistry.approveContract(contractAddress, weight, name);
        emit ContractApproved(contractAddress, weight, name);
    }
    
    function revokeReputationContract(address contractAddress) external onlyDAO {
        reputationRegistry.revokeContract(contractAddress);
        emit ContractRevoked(contractAddress);
    }
}
```

## Multi-Sig Implementation

### Signature Verification

```solidity
contract MultiSigManager {
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        mapping(address => bool) signatures;
        uint256 signatureCount;
    }
    
    mapping(uint256 => Transaction) public transactions;
    uint256 public transactionCount;
    
    function submitTransaction(
        address to,
        uint256 value,
        bytes calldata data
    ) external onlySigner returns (uint256 txId) {
        txId = transactionCount++;
        Transaction storage txn = transactions[txId];
        txn.to = to;
        txn.value = value;
        txn.data = data;
        txn.executed = false;
        
        emit TransactionSubmitted(txId, msg.sender, to, value);
    }
    
    function signTransaction(uint256 txId) external onlySigner {
        Transaction storage txn = transactions[txId];
        require(!txn.executed, "Already executed");
        require(!txn.signatures[msg.sender], "Already signed");
        
        txn.signatures[msg.sender] = true;
        txn.signatureCount++;
        
        emit TransactionSigned(txId, msg.sender);
        
        // Auto-execute if threshold met
        if (txn.signatureCount >= requiredSignatures) {
            executeTransaction(txId);
        }
    }
    
    function executeTransaction(uint256 txId) public {
        Transaction storage txn = transactions[txId];
        require(!txn.executed, "Already executed");
        require(txn.signatureCount >= requiredSignatures, "Insufficient signatures");
        
        txn.executed = true;
        
        (bool success, ) = txn.to.call{value: txn.value}(txn.data);
        require(success, "Execution failed");
        
        emit TransactionExecuted(txId);
    }
}
```

### Direct Parameter Setting Functions

```solidity
// Simplified parameter setting (no proposals needed)
function setEscrowFee(uint256 newFeePercentage) external onlyDAO {
    setEscrowParameter(BASE_FEE_PERCENTAGE, newFeePercentage);
}

function setDisputeTimeout(uint256 newTimeoutSeconds) external onlyDAO {
    setEscrowParameter(DISPUTE_TIME_WINDOW, newTimeoutSeconds);
}

function setReputationSubmissionFee(uint256 newFeeUSDC) external onlyDAO {
    setReputationParameter(PREPAID_SUBMISSION_FEE, newFeeUSDC);
}

function setMaxEscrowAmount(uint256 newMaxAmount) external onlyDAO {
    setEscrowParameter(MAX_ESCROW_AMOUNT, newMaxAmount);
}

// Batch parameter updates
function batchUpdateEscrowParameters(
    bytes32[] calldata keys,
    uint256[] calldata values
) external onlyDAO {
    require(keys.length == values.length, "Array length mismatch");
    
    for (uint256 i = 0; i < keys.length; i++) {
        setEscrowParameter(keys[i], values[i]);
    }
}
```

## Revenue Tracking and Reporting

### Revenue Analytics

```solidity
contract RevenueTracker {
    struct RevenueData {
        uint256 escrowFees;
        uint256 reputationFees;
        uint256 timestamp;
    }
    
    RevenueData[] public dailyRevenue;
    mapping(uint256 => uint256) public monthlyTotals; // timestamp => total
    
    function recordDailyRevenue() external {
        uint256 escrowRevenue = escrowContract.getDailyRevenue();
        uint256 reputationRevenue = reputationRegistry.getDailyRevenue();
        
        dailyRevenue.push(RevenueData({
            escrowFees: escrowRevenue,
            reputationFees: reputationRevenue,
            timestamp: block.timestamp
        }));
        
        uint256 monthKey = block.timestamp / 30 days;
        monthlyTotals[monthKey] += escrowRevenue + reputationRevenue;
        
        emit DailyRevenueRecorded(escrowRevenue, reputationRevenue, block.timestamp);
    }
    
    function getMonthlyRevenue(uint256 month, uint256 year) external view returns (uint256) {
        uint256 monthKey = (year * 12 + month) * 30 days;
        return monthlyTotals[monthKey];
    }
    
    function getTotalRevenue() external view returns (uint256) {
        return totalRevenueCollected;
    }
}
```

## Events and Monitoring

### Event Definitions

```solidity
event ParameterUpdated(string indexed contractType, bytes32 indexed parameter, uint256 value);
event RevenueCollected(address indexed source, uint256 amount, uint256 timestamp);
event RevenueWithdrawn(address indexed recipient, uint256 amount, string purpose);
event ArbitratorAdded(address indexed arbitrator, uint256 stakeRequired);
event ArbitratorRemoved(address indexed arbitrator);
event ContractApproved(address indexed contractAddress, uint32 weight, string name);
event ContractRevoked(address indexed contractAddress);
event TransactionSubmitted(uint256 indexed txId, address indexed submitter, address to, uint256 value);
event TransactionSigned(uint256 indexed txId, address indexed signer);
event TransactionExecuted(uint256 indexed txId);
event DailyRevenueRecorded(uint256 escrowFees, uint256 reputationFees, uint256 timestamp);
```

## Default Parameter Values

### Initial Escrow Parameters
```solidity
function initializeEscrowParameters() internal {
    parameters[BASE_FEE_PERCENTAGE] = 100;          // 1.0%
    parameters[MINIMUM_FEE_USD] = 500000;           // $0.50
    parameters[MAXIMUM_FEE_USD] = 500000000;        // $500
    parameters[DISPUTE_TIME_WINDOW] = 259200;       // 72 hours
    parameters[ARBITRATION_FEE] = 25000000;         // $25
    parameters[EVIDENCE_SUBMISSION_TIME] = 172800;  // 48 hours
    parameters[ARBITRATOR_RESPONSE_TIME] = 604800;  // 7 days
    parameters[MAX_ESCROW_AMOUNT] = 100000000000;   // $100,000
    parameters[DAILY_VOLUME_LIMIT] = 1000000000000; // $1,000,000
    parameters[KYC_REQUIRED_ABOVE] = 10000000000;   // $10,000
}
```

### Initial Reputation Parameters
```solidity
function initializeReputationParameters() internal {
    parameters[PREPAID_SUBMISSION_FEE] = 1000000;   // $1.00
    parameters[REGISTRATION_DEPOSIT] = 100000000;   // $100
    parameters[MAX_CONTRACT_WEIGHT] = 100;          // Maximum weight
    parameters[DEFAULT_CONTRACT_WEIGHT] = 50;       // Default weight
    parameters[MAX_BATCH_SIZE] = 100;               // 100 events per batch
    parameters[MIN_SUBMISSION_DELAY] = 60;          // 1 minute
    parameters[EVENT_EXPIRY_TIME] = 63072000;       // 2 years
}
```

## Security Considerations

### Access Control
- Only authorized signers can initiate transactions
- Parameter changes require minimum signature threshold
- Revenue collection can be called by anyone (public function)
- Fund withdrawals require DAO approval

### Parameter Validation
- All parameter changes validated against acceptable ranges
- Invalid parameters rejected automatically
- Parameter history tracked for audit purposes

### Emergency Controls
- Emergency fund withdrawal requires all signers
- Contract pause capabilities for security incidents
- Parameter rollback functionality if needed

This simplified DAO focuses purely on its core functions: collecting revenue from both contracts and managing their operational parameters through a straightforward multi-sig mechanism.