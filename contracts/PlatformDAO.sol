// SPDX-License-Identifier: ISC
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "./interfaces/IPlatformDAO.sol";
import "./interfaces/IP2PEscrow.sol";
import "./interfaces/IReputationRegistry.sol";
import "./libraries/ParameterKeys.sol";
import "./libraries/Events.sol";

/**
 * @title PlatformDAO
 * @notice A multi-signature DAO contract for governing the P2P Platform
 * @dev Manages revenue collection, parameter updates, and contract governance
 */
contract PlatformDAO is IPlatformDAO, ReentrancyGuard, Pausable, AccessControl {
    using SafeERC20 for IERC20;

    // ============ CONSTANTS ============
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // USDC contract address
    IERC20 public immutable USDC;

    // ============ STATE VARIABLES ============

    // Governed contracts
    IP2PEscrow public escrowContract;
    IReputationRegistry public reputationRegistry;

    // Multi-sig configuration
    address[] public signers;
    uint256 public requiredSignatures;
    mapping(address => bool) public isSigner;

    // Transaction management
    struct MultiSigTransaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 signatureCount;
        mapping(address => bool) signatures;
        uint256 createdAt;
        string description;
    }

    mapping(uint256 => MultiSigTransaction) public transactions;
    uint256 public transactionCount;

    // Parameter management
    mapping(bytes32 => uint256) public parameters;
    mapping(bytes32 => bool) public parameterExists;

    // Revenue tracking
    uint256 public totalRevenueCollected;
    uint256 public lastCollectionTimestamp;




    // ============ EVENTS ============
    // Note: Events are defined in IPlatformDAO interface

    // ============ MODIFIERS ============

    modifier onlySigner() {
        require(hasRole(SIGNER_ROLE, msg.sender), "PlatformDAO: caller is not a signer");
        _;
    }

    modifier onlyDAO() {
        require(msg.sender == address(this), "PlatformDAO: only DAO can call");
        _;
    }

    modifier validTransaction(uint256 txId) {
        require(txId < transactionCount, "PlatformDAO: invalid transaction ID");
        _;
    }

    // ============ CONSTRUCTOR ============

    constructor(
        address[] memory _initialSigners,
        uint256 _requiredSignatures,
        address _escrowContract,
        address _reputationRegistry,
        address defaultAdmin,
        address initialPauser,
        address _usdcToken
    ) {
        require(_initialSigners.length >= 2, "PlatformDAO: need at least 2 signers");
        require(_requiredSignatures >= 2, "PlatformDAO: need at least 2 required signatures");
        require(_requiredSignatures <= _initialSigners.length, "PlatformDAO: required signatures exceeds signer count");
        require(_escrowContract != address(0), "PlatformDAO: invalid escrow contract");
        require(_reputationRegistry != address(0), "PlatformDAO: invalid reputation contract");
        require(_usdcToken != address(0), "PlatformDAO: invalid USDC token");

        USDC = IERC20(_usdcToken);
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, initialPauser);

        // Set up multi-sig
        for (uint256 i = 0; i < _initialSigners.length; i++) {
            address signer = _initialSigners[i];
            require(signer != address(0), "PlatformDAO: invalid signer address");
            require(!isSigner[signer], "PlatformDAO: duplicate signer");

            signers.push(signer);
            isSigner[signer] = true;
            _grantRole(SIGNER_ROLE, signer);
        }

        requiredSignatures = _requiredSignatures;

        // Set governed contracts
        escrowContract = IP2PEscrow(_escrowContract);
        reputationRegistry = IReputationRegistry(_reputationRegistry);

        // Initialize parameters
        _initializeParameters();
    }

    // ============ INITIALIZATION ============

    function _initializeParameters() internal {
        // Initialize escrow parameters
        (bytes32[] memory escrowKeys, uint256[] memory escrowValues) = ParameterKeys.getDefaultEscrowParameters();
        for (uint256 i = 0; i < escrowKeys.length; i++) {
            parameters[escrowKeys[i]] = escrowValues[i];
            parameterExists[escrowKeys[i]] = true;
        }

        // Initialize reputation parameters
        (bytes32[] memory repKeys, uint256[] memory repValues) = ParameterKeys.getDefaultReputationParameters();
        for (uint256 i = 0; i < repKeys.length; i++) {
            parameters[repKeys[i]] = repValues[i];
            parameterExists[repKeys[i]] = true;
        }
    }

    // ============ MULTI-SIG TRANSACTION MANAGEMENT ============

    /**
     * @notice Submit a new transaction for multi-sig approval
     * @param to Target contract address
     * @param value ETH value to send
     * @param data Transaction data
     * @param description Human-readable description
     * @return txId Transaction ID
     */
    function submitTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        string calldata description
    ) external override onlySigner nonReentrant returns (uint256 txId) {
        require(to != address(0), "PlatformDAO: invalid target address");
        require(bytes(description).length > 0, "PlatformDAO: description required");

        txId = transactionCount++;
        
        MultiSigTransaction storage txn = transactions[txId];
        txn.to = to;
        txn.value = value;
        txn.data = data;
        txn.executed = false;
        txn.signatureCount = 0;
        txn.createdAt = block.timestamp;
        txn.description = description;

        emit Events.TransactionSubmitted(txId, msg.sender, to, value, data);
        
        return txId;
    }

    /**
     * @notice Sign a submitted transaction
     * @param txId Transaction ID to sign
     */
    function signTransaction(uint256 txId) external override onlySigner validTransaction(txId) nonReentrant {
        MultiSigTransaction storage txn = transactions[txId];
        
        require(!txn.executed, "PlatformDAO: transaction already executed");
        require(!txn.signatures[msg.sender], "PlatformDAO: already signed by caller");

        txn.signatures[msg.sender] = true;
        txn.signatureCount++;

        emit Events.TransactionSigned(txId, msg.sender, txn.signatureCount);

        // Auto-execute if threshold met
        if (txn.signatureCount >= requiredSignatures) {
            _executeTransaction(txId);
        }
    }

    /**
     * @notice Execute a transaction with sufficient signatures
     * @param txId Transaction ID to execute
     */
    function executeTransaction(uint256 txId) external override validTransaction(txId) nonReentrant {
        MultiSigTransaction storage txn = transactions[txId];
        
        require(!txn.executed, "PlatformDAO: transaction already executed");
        require(txn.signatureCount >= requiredSignatures, "PlatformDAO: insufficient signatures");

        _executeTransaction(txId);
    }

    function _executeTransaction(uint256 txId) internal {
        MultiSigTransaction storage txn = transactions[txId];
        txn.executed = true;

        (bool success, ) = txn.to.call{value: txn.value}(txn.data);
        require(success, "PlatformDAO: transaction execution failed");

        emit Events.TransactionExecuted(txId, msg.sender, success);
    }

    // ============ SIGNER MANAGEMENT ============

    /**
     * @notice Add a new signer (requires DAO approval)
     * @param newSigner Address of the new signer
     */
    function addSigner(address newSigner) external override onlyDAO {
        require(newSigner != address(0), "PlatformDAO: invalid signer address");
        require(!isSigner[newSigner], "PlatformDAO: already a signer");

        signers.push(newSigner);
        isSigner[newSigner] = true;
        _grantRole(SIGNER_ROLE, newSigner);

        emit Events.SignerAdded(newSigner, signers.length);
    }

    /**
     * @notice Remove a signer (requires DAO approval)
     * @param signer Address of the signer to remove
     */
    function removeSigner(address signer) external override onlyDAO {
        require(isSigner[signer], "PlatformDAO: not a signer");
        require(signers.length > requiredSignatures, "PlatformDAO: cannot remove, would fall below required signatures");

        // Remove from signers array
        for (uint256 i = 0; i < signers.length; i++) {
            if (signers[i] == signer) {
                signers[i] = signers[signers.length - 1];
                signers.pop();
                break;
            }
        }

        isSigner[signer] = false;
        _revokeRole(SIGNER_ROLE, signer);

        emit Events.SignerRemoved(signer, signers.length);
    }

    /**
     * @notice Change required signatures threshold (requires DAO approval)
     * @param newRequired New required signatures count
     */
    function changeRequiredSignatures(uint256 newRequired) external override onlyDAO {
        require(newRequired >= 2, "PlatformDAO: need at least 2 required signatures");
        require(newRequired <= signers.length, "PlatformDAO: required signatures exceeds signer count");

        uint256 oldRequired = requiredSignatures;
        requiredSignatures = newRequired;

        emit Events.RequiredSignaturesChanged(oldRequired, newRequired);
    }

    // ============ REVENUE COLLECTION ============

    /**
     * @notice Collect revenue from escrow contract
     */
    function collectEscrowRevenue() public override nonReentrant {
        uint256 balance = escrowContract.getDAOBalance();
        if (balance > 0) {
            escrowContract.withdrawDAOFunds(balance, address(USDC));
            totalRevenueCollected += balance;
            lastCollectionTimestamp = block.timestamp;
            
            emit Events.RevenueCollected(address(escrowContract), balance, block.timestamp, "P2PEscrow");
        }
    }

    /**
     * @notice Collect revenue from reputation registry
     */
    function collectReputationRevenue() public override nonReentrant {
        uint256 fees = reputationRegistry.getTotalFeesCollected();
        if (fees > 0) {
            reputationRegistry.withdrawFees(fees);
            totalRevenueCollected += fees;
            lastCollectionTimestamp = block.timestamp;
            
            emit Events.RevenueCollected(address(reputationRegistry), fees, block.timestamp, "ReputationRegistry");
        }
    }

    /**
     * @notice Collect revenue from both contracts
     */
    function collectAllRevenue() external override {
        collectEscrowRevenue();
        collectReputationRevenue();
    }

    /**
     * @notice Withdraw funds from DAO treasury (requires DAO approval)
     * @param recipient Address to send funds to
     * @param amount Amount to withdraw
     * @param purpose Purpose of withdrawal
     */
    function withdrawFunds(
        address recipient,
        uint256 amount,
        string calldata purpose
    ) external override onlyDAO nonReentrant {
        require(recipient != address(0), "PlatformDAO: invalid recipient");
        require(amount > 0, "PlatformDAO: invalid amount");
        require(amount <= USDC.balanceOf(address(this)), "PlatformDAO: insufficient balance");
        require(bytes(purpose).length > 0, "PlatformDAO: purpose required");

        USDC.safeTransfer(recipient, amount);
        
        emit Events.RevenueWithdrawn(recipient, amount, purpose, msg.sender);
    }

    // ============ PARAMETER MANAGEMENT ============

    /**
     * @notice Set escrow contract parameter (requires DAO approval)
     * @param parameterKey Parameter key
     * @param value New parameter value
     */
    function setEscrowParameter(bytes32 parameterKey, uint256 value) public override onlyDAO {
        require(_isValidEscrowParameter(parameterKey, value), "PlatformDAO: invalid escrow parameter");

        uint256 oldValue = parameters[parameterKey];
        parameters[parameterKey] = value;
        parameterExists[parameterKey] = true;

        // Update the escrow contract
        escrowContract.updateParameter(parameterKey, value);

        emit Events.ParameterUpdated("ESCROW", parameterKey, oldValue, value, msg.sender);
    }

    /**
     * @notice Set reputation registry parameter (requires DAO approval)
     * @param parameterKey Parameter key
     * @param value New parameter value
     */
    function setReputationParameter(bytes32 parameterKey, uint256 value) public override onlyDAO {
        require(_isValidReputationParameter(parameterKey, value), "PlatformDAO: invalid reputation parameter");

        uint256 oldValue = parameters[parameterKey];
        parameters[parameterKey] = value;
        parameterExists[parameterKey] = true;

        // Update the reputation registry
        reputationRegistry.updateParameter(parameterKey, value);

        emit Events.ParameterUpdated("REPUTATION", parameterKey, oldValue, value, msg.sender);
    }

    /**
     * @notice Batch update escrow parameters (requires DAO approval)
     * @param keys Array of parameter keys
     * @param values Array of parameter values
     */
    function batchUpdateEscrowParameters(
        bytes32[] calldata keys,
        uint256[] calldata values
    ) external override onlyDAO {
        require(keys.length == values.length, "PlatformDAO: array length mismatch");
        require(keys.length > 0, "PlatformDAO: empty arrays");

        for (uint256 i = 0; i < keys.length; i++) {
            setEscrowParameter(keys[i], values[i]);
        }
    }

    /**
     * @notice Batch update reputation parameters (requires DAO approval)
     * @param keys Array of parameter keys
     * @param values Array of parameter values
     */
    function batchUpdateReputationParameters(
        bytes32[] calldata keys,
        uint256[] calldata values
    ) external override onlyDAO {
        require(keys.length == values.length, "PlatformDAO: array length mismatch");
        require(keys.length > 0, "PlatformDAO: empty arrays");

        for (uint256 i = 0; i < keys.length; i++) {
            setReputationParameter(keys[i], values[i]);
        }
    }

    // ============ CONTRACT MANAGEMENT ============

    /**
     * @notice Add authorized arbitrator to escrow contract (requires DAO approval)
     * @param arbitrator Arbitrator address
     * @param stakeRequired Required stake amount
     */
    function addArbitrator(address arbitrator, uint256 stakeRequired) external override onlyDAO {
        require(arbitrator != address(0), "PlatformDAO: invalid arbitrator address");
        require(stakeRequired > 0, "PlatformDAO: stake required must be positive");

        escrowContract.addAuthorizedArbitrator(arbitrator, stakeRequired);
        
        emit Events.ArbitratorAdded(arbitrator, stakeRequired, msg.sender);
    }

    /**
     * @notice Remove arbitrator from escrow contract (requires DAO approval)
     * @param arbitrator Arbitrator address to remove
     */
    function removeArbitrator(address arbitrator) external override onlyDAO {
        require(arbitrator != address(0), "PlatformDAO: invalid arbitrator address");

        escrowContract.removeAuthorizedArbitrator(arbitrator);
        
        emit Events.ArbitratorRemoved(arbitrator, msg.sender, "Removed by DAO");
    }

    /**
     * @notice Approve contract in reputation registry (requires DAO approval)
     * @param contractAddr Contract address to approve
     * @param weight Reputation weight (0-100)
     * @param name Contract name
     */
    function approveReputationContract(
        address contractAddr,
        uint32 weight,
        string calldata name
    ) external override onlyDAO {
        require(contractAddr != address(0), "PlatformDAO: invalid contract address");
        require(weight <= parameters[ParameterKeys.MAX_CONTRACT_WEIGHT], "PlatformDAO: weight exceeds maximum");
        require(bytes(name).length > 0, "PlatformDAO: name required");

        reputationRegistry.approveContract(contractAddr, weight, name);
        
        emit Events.ContractApproved(contractAddr, weight, name);
    }

    /**
     * @notice Revoke contract from reputation registry (requires DAO approval)
     * @param contractAddr Contract address to revoke
     * @param reason Reason for revocation
     */
    function revokeReputationContract(address contractAddr, string calldata reason) external override onlyDAO {
        require(contractAddr != address(0), "PlatformDAO: invalid contract address");
        require(bytes(reason).length > 0, "PlatformDAO: reason required");

        reputationRegistry.revokeContract(contractAddr, reason);
        
        emit Events.ContractRevoked(contractAddr, reason);
    }



    // ============ VIEW FUNCTIONS ============

    /**
     * @notice Get DAO treasury balance
     * @return Current USDC balance
     */
    function getTreasuryBalance() external view override returns (uint256) {
        return USDC.balanceOf(address(this));
    }

    /**
     * @notice Get total revenue collected
     * @return Total revenue collected
     */
    function getTotalRevenue() external view override returns (uint256) {
        return totalRevenueCollected;
    }

    /**
     * @notice Get monthly revenue
     * @param month Month (1-12)
     * @param year Year
     * @return Monthly revenue total
     */




    /**
     * @notice Get transaction details
     * @param txId Transaction ID
     * @return to Target address
     * @return value ETH value
     * @return data Transaction data
     * @return executed Whether executed
     * @return signatureCount Number of signatures
     * @return description Transaction description
     */
    function getTransaction(uint256 txId) external view override validTransaction(txId) returns (
        address to,
        uint256 value,
        bytes memory data,
        bool executed,
        uint256 signatureCount,
        string memory description
    ) {
        MultiSigTransaction storage txn = transactions[txId];
        return (
            txn.to,
            txn.value,
            txn.data,
            txn.executed,
            txn.signatureCount,
            txn.description
        );
    }

    /**
     * @notice Check if address has signed a transaction
     * @param txId Transaction ID
     * @param signer Signer address
     * @return Whether the signer has signed
     */
    function hasSignedTransaction(uint256 txId, address signer) external view override validTransaction(txId) returns (bool) {
        return transactions[txId].signatures[signer];
    }

    /**
     * @notice Get all signers
     * @return Array of signer addresses
     */
    function getSigners() external view override returns (address[] memory) {
        return signers;
    }

    /**
     * @notice Get parameter value
     * @param key Parameter key
     * @return Parameter value
     */
    function getParameter(bytes32 key) external view override returns (uint256) {
        return parameters[key];
    }

    // ============ PARAMETER VALIDATION ============

    function _isValidEscrowParameter(bytes32 key, uint256 value) internal pure returns (bool) {
        if (key == ParameterKeys.BASE_FEE_PERCENTAGE) return value >= 10 && value <= 200;        // 0.1% - 2.0%
        if (key == ParameterKeys.MINIMUM_FEE_USD) return value >= 100000 && value <= 5000000;    // $0.10 - $5.00
        if (key == ParameterKeys.MAXIMUM_FEE_USD) return value >= 100000000 && value <= 1000000000; // $100 - $1,000
        if (key == ParameterKeys.DISPUTE_TIME_WINDOW) return value >= 86400 && value <= 604800;  // 1-7 days
        if (key == ParameterKeys.ARBITRATION_FEE) return value >= 10000000 && value <= 100000000; // $10 - $100
        if (key == ParameterKeys.EVIDENCE_SUBMISSION_TIME) return value >= 86400 && value <= 259200; // 1-3 days
        if (key == ParameterKeys.ARBITRATOR_RESPONSE_TIME) return value >= 86400 && value <= 1209600; // 1-14 days
        if (key == ParameterKeys.MAX_ESCROW_AMOUNT) return value >= 1000000000 && value <= 1000000000000; // $1,000 - $1M
        if (key == ParameterKeys.DAILY_VOLUME_LIMIT) return value >= 100000000000 && value <= 10000000000000; // $100K - $10M
        if (key == ParameterKeys.KYC_REQUIRED_ABOVE) return value >= 1000000000 && value <= 100000000000; // $1,000 - $100K
        return false;
    }

    function _isValidReputationParameter(bytes32 key, uint256 value) internal pure returns (bool) {
        if (key == ParameterKeys.PREPAID_SUBMISSION_FEE) return value >= 500000 && value <= 5000000;    // $0.50 - $5.00
        if (key == ParameterKeys.REGISTRATION_DEPOSIT) return value >= 50000000 && value <= 500000000; // $50 - $500
        if (key == ParameterKeys.MAX_CONTRACT_WEIGHT) return value >= 1 && value <= 100;               // 1-100
        if (key == ParameterKeys.DEFAULT_CONTRACT_WEIGHT) return value >= 1 && value <= 100;           // 1-100
        if (key == ParameterKeys.MAX_BATCH_SIZE) return value >= 10 && value <= 500;                   // 10-500 events
        if (key == ParameterKeys.MIN_SUBMISSION_DELAY) return value >= 30 && value <= 3600;            // 30s - 1hr
        if (key == ParameterKeys.EVENT_EXPIRY_TIME) return value >= 31536000 && value <= 157680000;    // 1-5 years
        return false;
    }

    // ============ ADMIN FUNCTIONS ============

    /**
     * @notice Pause the contract (emergency)
     */
    function pause() external {
        require(hasRole(PAUSER_ROLE, msg.sender), "PlatformDAO: caller cannot pause");
        _pause();
    }

    /**
     * @notice Unpause the contract
     */
    function unpause() external onlyDAO {
        _unpause();
    }

    /**
     * @notice Emergency fund withdrawal (requires all signers)
     * @param recipient Recipient address
     */
    function emergencyWithdraw(address recipient) external override {
        require(recipient != address(0), "PlatformDAO: invalid recipient");
        
        // Check that all signers have approved this
        uint256 approvalCount = 0;
        for (uint256 i = 0; i < signers.length; i++) {
            if (hasRole(SIGNER_ROLE, signers[i])) {
                approvalCount++;
            }
        }
        
        require(approvalCount == signers.length, "PlatformDAO: requires all signers");
        
        uint256 balance = USDC.balanceOf(address(this));
        if (balance > 0) {
            USDC.safeTransfer(recipient, balance);
            emit RevenueWithdrawn(recipient, balance, "EMERGENCY");
        }
    }
}