// SPDX-License-Identifier: ISC
pragma solidity ^0.8.20;

/**
 * @title ParameterKeys
 * @notice Library containing all parameter keys used across the platform
 * @dev Centralizes parameter key definitions to ensure consistency
 */
library ParameterKeys {
    // ============ P2P ESCROW PARAMETERS ============
    
    // Fee structure parameters
    bytes32 public constant BASE_FEE_PERCENTAGE = keccak256("BASE_FEE_PERCENTAGE");         // Escrow fee percentage (100 = 1.0%)
    bytes32 public constant MINIMUM_FEE_USD = keccak256("MINIMUM_FEE_USD");                 // Minimum fee in USDC (6 decimals)
    bytes32 public constant MAXIMUM_FEE_USD = keccak256("MAXIMUM_FEE_USD");                 // Maximum fee in USDC (6 decimals)
    
    // Dispute parameters
    bytes32 public constant DISPUTE_TIME_WINDOW = keccak256("DISPUTE_TIME_WINDOW");         // Time window for raising disputes (seconds)
    bytes32 public constant ARBITRATION_FEE = keccak256("ARBITRATION_FEE");                 // Arbitration fee in USDC (6 decimals)
    bytes32 public constant EVIDENCE_SUBMISSION_TIME = keccak256("EVIDENCE_SUBMISSION_TIME"); // Time for evidence submission (seconds)
    bytes32 public constant ARBITRATOR_RESPONSE_TIME = keccak256("ARBITRATOR_RESPONSE_TIME");  // Time for arbitrator response (seconds)
    
    // Security and limits parameters
    bytes32 public constant MAX_ESCROW_AMOUNT = keccak256("MAX_ESCROW_AMOUNT");             // Maximum escrow amount in USDC (6 decimals)
    bytes32 public constant DAILY_VOLUME_LIMIT = keccak256("DAILY_VOLUME_LIMIT");           // Daily volume limit per user in USDC (6 decimals)
    bytes32 public constant KYC_REQUIRED_ABOVE = keccak256("KYC_REQUIRED_ABOVE");           // KYC requirement threshold in USDC (6 decimals)
    
    // Timeout parameters
    bytes32 public constant PROPOSAL_TIMEOUT = keccak256("PROPOSAL_TIMEOUT");               // Proposal expiration time (seconds)
    bytes32 public constant REFUND_TIMEOUT = keccak256("REFUND_TIMEOUT");                   // Refund request timeout (seconds)
    bytes32 public constant FUNDING_TIMEOUT = keccak256("FUNDING_TIMEOUT");                 // Funding timeout after acceptance (seconds)
    
    // ============ REPUTATION REGISTRY PARAMETERS ============
    
    // Submission fee parameters
    bytes32 public constant PREPAID_SUBMISSION_FEE = keccak256("PREPAID_SUBMISSION_FEE");   // Fee per submission in USDC (6 decimals)
    bytes32 public constant REGISTRATION_DEPOSIT = keccak256("REGISTRATION_DEPOSIT");       // Minimum registration deposit in USDC (6 decimals)
    
    // Contract weight parameters
    bytes32 public constant MAX_CONTRACT_WEIGHT = keccak256("MAX_CONTRACT_WEIGHT");         // Maximum contract weight (0-100)
    bytes32 public constant DEFAULT_CONTRACT_WEIGHT = keccak256("DEFAULT_CONTRACT_WEIGHT"); // Default contract weight (0-100)
    
    // Data quality parameters
    bytes32 public constant MAX_BATCH_SIZE = keccak256("MAX_BATCH_SIZE");                   // Maximum batch size for operations
    bytes32 public constant MIN_SUBMISSION_DELAY = keccak256("MIN_SUBMISSION_DELAY");       // Minimum delay between submissions (seconds)
    bytes32 public constant EVENT_EXPIRY_TIME = keccak256("EVENT_EXPIRY_TIME");             // Event expiry time (seconds)
    
    // Credit system parameters
    bytes32 public constant MIN_CREDIT_BALANCE = keccak256("MIN_CREDIT_BALANCE");           // Minimum credit balance to maintain
    bytes32 public constant CREDIT_REFILL_THRESHOLD = keccak256("CREDIT_REFILL_THRESHOLD"); // Auto-refill threshold
    bytes32 public constant MAX_CREDIT_BALANCE = keccak256("MAX_CREDIT_BALANCE");           // Maximum credit balance
    
    // ============ PLATFORM DAO PARAMETERS ============
    
    // Multi-sig parameters
    bytes32 public constant MIN_REQUIRED_SIGNATURES = keccak256("MIN_REQUIRED_SIGNATURES"); // Minimum required signatures
    bytes32 public constant MAX_SIGNERS = keccak256("MAX_SIGNERS");                         // Maximum number of signers
    bytes32 public constant TRANSACTION_TIMEOUT = keccak256("TRANSACTION_TIMEOUT");         // Transaction execution timeout
    
    // Revenue collection parameters
    bytes32 public constant REVENUE_COLLECTION_INTERVAL = keccak256("REVENUE_COLLECTION_INTERVAL"); // Auto-collection interval
    bytes32 public constant MIN_COLLECTION_AMOUNT = keccak256("MIN_COLLECTION_AMOUNT");     // Minimum amount to trigger collection
    bytes32 public constant TREASURY_RESERVE_RATIO = keccak256("TREASURY_RESERVE_RATIO");   // Percentage to keep in reserve
    
    // Governance parameters
    bytes32 public constant PARAMETER_CHANGE_DELAY = keccak256("PARAMETER_CHANGE_DELAY");   // Delay before parameter changes take effect
    bytes32 public constant EMERGENCY_PAUSE_DURATION = keccak256("EMERGENCY_PAUSE_DURATION"); // Duration of emergency pause
    bytes32 public constant GOVERNANCE_PROPOSAL_THRESHOLD = keccak256("GOVERNANCE_PROPOSAL_THRESHOLD"); // Threshold for proposals
    
    // ============ DEFAULT VALUES ============
    
    /**
     * @notice Get default parameter values for escrow contract
     * @return keys Array of parameter keys
     * @return values Array of parameter default values
     */
    function getDefaultEscrowParameters() internal pure returns (bytes32[] memory keys, uint256[] memory values) {
        keys = new bytes32[](10);
        values = new uint256[](10);
        
        keys[0] = BASE_FEE_PERCENTAGE;
        values[0] = 100; // 1.0%
        
        keys[1] = MINIMUM_FEE_USD;
        values[1] = 500000; // $0.50 (6 decimals)
        
        keys[2] = MAXIMUM_FEE_USD;
        values[2] = 500000000; // $500 (6 decimals)
        
        keys[3] = DISPUTE_TIME_WINDOW;
        values[3] = 259200; // 72 hours
        
        keys[4] = ARBITRATION_FEE;
        values[4] = 25000000; // $25 (6 decimals)
        
        keys[5] = EVIDENCE_SUBMISSION_TIME;
        values[5] = 172800; // 48 hours
        
        keys[6] = ARBITRATOR_RESPONSE_TIME;
        values[6] = 604800; // 7 days
        
        keys[7] = MAX_ESCROW_AMOUNT;
        values[7] = 100000000000; // $100,000 (6 decimals)
        
        keys[8] = DAILY_VOLUME_LIMIT;
        values[8] = 1000000000000; // $1,000,000 (6 decimals)
        
        keys[9] = KYC_REQUIRED_ABOVE;
        values[9] = 10000000000; // $10,000 (6 decimals)
    }
    
    /**
     * @notice Get default parameter values for reputation registry
     * @return keys Array of parameter keys
     * @return values Array of parameter default values
     */
    function getDefaultReputationParameters() internal pure returns (bytes32[] memory keys, uint256[] memory values) {
        keys = new bytes32[](8);
        values = new uint256[](8);
        
        keys[0] = PREPAID_SUBMISSION_FEE;
        values[0] = 1000000; // $1.00 (6 decimals)
        
        keys[1] = REGISTRATION_DEPOSIT;
        values[1] = 100000000; // $100 (6 decimals)
        
        keys[2] = MAX_CONTRACT_WEIGHT;
        values[2] = 100; // Maximum weight
        
        keys[3] = DEFAULT_CONTRACT_WEIGHT;
        values[3] = 50; // Default weight
        
        keys[4] = MAX_BATCH_SIZE;
        values[4] = 100; // 100 events per batch
        
        keys[5] = MIN_SUBMISSION_DELAY;
        values[5] = 60; // 1 minute
        
        keys[6] = EVENT_EXPIRY_TIME;
        values[6] = 63072000; // 2 years
        
        keys[7] = MAX_CREDIT_BALANCE;
        values[7] = 1000000000; // $1,000 (6 decimals)
    }
    
    /**
     * @notice Validate parameter value ranges for escrow contract
     * @param key The parameter key to validate
     * @param value The parameter value to validate
     * @return True if the parameter value is valid
     */
    function isValidEscrowParameter(bytes32 key, uint256 value) internal pure returns (bool) {
        if (key == BASE_FEE_PERCENTAGE) return value >= 10 && value <= 200; // 0.1% - 2.0%
        if (key == MINIMUM_FEE_USD) return value >= 100000 && value <= 5000000; // $0.10 - $5.00
        if (key == MAXIMUM_FEE_USD) return value >= 100000000 && value <= 1000000000; // $100 - $1,000
        if (key == DISPUTE_TIME_WINDOW) return value >= 86400 && value <= 604800; // 1-7 days
        if (key == ARBITRATION_FEE) return value >= 10000000 && value <= 100000000; // $10 - $100
        if (key == EVIDENCE_SUBMISSION_TIME) return value >= 86400 && value <= 259200; // 1-3 days
        if (key == ARBITRATOR_RESPONSE_TIME) return value >= 86400 && value <= 1209600; // 1-14 days
        if (key == MAX_ESCROW_AMOUNT) return value >= 1000000000 && value <= 1000000000000; // $1,000 - $1M
        if (key == DAILY_VOLUME_LIMIT) return value >= 100000000000 && value <= 10000000000000; // $100K - $10M
        if (key == KYC_REQUIRED_ABOVE) return value >= 1000000000 && value <= 100000000000; // $1,000 - $100K
        return false;
    }
    
    /**
     * @notice Validate parameter value ranges for reputation registry
     * @param key The parameter key to validate
     * @param value The parameter value to validate
     * @return True if the parameter value is valid
     */
    function isValidReputationParameter(bytes32 key, uint256 value) internal pure returns (bool) {
        if (key == PREPAID_SUBMISSION_FEE) return value >= 500000 && value <= 5000000; // $0.50 - $5.00
        if (key == REGISTRATION_DEPOSIT) return value >= 50000000 && value <= 500000000; // $50 - $500
        if (key == MAX_CONTRACT_WEIGHT) return value >= 1 && value <= 100; // 1-100
        if (key == DEFAULT_CONTRACT_WEIGHT) return value >= 1 && value <= 100; // 1-100
        if (key == MAX_BATCH_SIZE) return value >= 10 && value <= 500; // 10-500 events
        if (key == MIN_SUBMISSION_DELAY) return value >= 30 && value <= 3600; // 30s - 1hr
        if (key == EVENT_EXPIRY_TIME) return value >= 31536000 && value <= 157680000; // 1-5 years
        if (key == MAX_CREDIT_BALANCE) return value >= 100000000 && value <= 10000000000; // $100 - $10,000
        return false;
    }
}