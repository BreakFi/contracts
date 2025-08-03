// SPDX-License-Identifier: ISC
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "./interfaces/IP2PEscrow.sol";
import "./interfaces/IERC20Extended.sol";
import "./libraries/ParameterKeys.sol";
import "./libraries/Events.sol";

/**
 * @title P2PEscrow
 * @notice Peer-to-peer escrow contract with bidirectional proposals and mutual consent
 * @dev Implements secure trading between two parties with dispute resolution
 */
contract P2PEscrow is IP2PEscrow, ReentrancyGuard, Pausable, AccessControl {
    using SafeERC20 for IERC20;
    using ParameterKeys for bytes32;

    // ============ CONSTANTS ============
    
    bytes32 public constant DAO_ROLE = keccak256("DAO_ROLE");
    bytes32 public constant ARBITRATOR_ROLE = keccak256("ARBITRATOR_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // ============ STATE VARIABLES ============
    
    // Core storage
    mapping(uint256 => Escrow) public escrows;
    mapping(uint256 => Dispute) public disputes;
    mapping(address => bool) public authorizedArbitrators;
    mapping(address => uint256) public arbitratorStakes;
    
    // Counters
    uint256 public escrowCount;
    uint256 public disputeCount;
    
    // Parameter storage
    mapping(bytes32 => uint256) public parameters;
    
    // Revenue tracking
    uint256 public totalFeesCollected;
    uint256 public daoBalance;

    
    // Rate limiting and security
    mapping(address => mapping(uint256 => uint256)) public dailyVolume; // user => day => volume
    
    // Supported tokens
    mapping(address => bool) public supportedTokens;
    mapping(address => uint8) public tokenDecimals;

    // ============ ADDITIONAL EVENTS ============
    // All events are now defined in libraries/Events.sol

    // ============ MODIFIERS ============
    
    modifier onlyDAO() {
        require(hasRole(DAO_ROLE, msg.sender), "P2PEscrow: caller is not DAO");
        _;
    }
    
    modifier onlyArbitrator() {
        require(hasRole(ARBITRATOR_ROLE, msg.sender) && authorizedArbitrators[msg.sender], "P2PEscrow: caller is not authorized arbitrator");
        _;
    }
    
    modifier validEscrow(uint256 escrowId) {
        require(escrowId < escrowCount, "P2PEscrow: invalid escrow ID");
        require(escrows[escrowId].state != EscrowState.NONE, "P2PEscrow: escrow does not exist");
        _;
    }
    
    modifier validDispute(uint256 disputeId) {
        require(disputeId < disputeCount, "P2PEscrow: invalid dispute ID");
        _;
    }
    
    modifier onlyParticipant(uint256 escrowId) {
        Escrow storage escrow = escrows[escrowId];
        require(
            msg.sender == escrow.buyer || msg.sender == escrow.seller,
            "P2PEscrow: caller is not a participant"
        );
        _;
    }

    // ============ CONSTRUCTOR ============
    
    constructor(address daoAddress) {
        require(daoAddress != address(0), "P2PEscrow: invalid DAO address");
        
        _grantRole(DEFAULT_ADMIN_ROLE, daoAddress);
        _grantRole(DAO_ROLE, daoAddress);
        _grantRole(PAUSER_ROLE, daoAddress);
        
        // Initialize default parameters
        _initializeParameters();
    }

    // ============ INITIALIZATION ============
    
    /**
     * @notice Initialize default parameter values
     * @dev Called in constructor to set up initial parameters
     */
    function _initializeParameters() internal {
        (bytes32[] memory keys, uint256[] memory values) = ParameterKeys.getDefaultEscrowParameters();
        
        for (uint256 i = 0; i < keys.length; i++) {
            parameters[keys[i]] = values[i];
        }
    }

    // ============ PROPOSAL MANAGEMENT FUNCTIONS ============
    
    /**
     * @notice Create a new escrow proposal
     * @param counterparty The address of the other party
     * @param cryptoToken The ERC20 token to be escrowed
     * @param cryptoAmount The amount of crypto tokens
     * @param fiatAmount The amount of fiat currency (in cents)
     * @param fiatCurrency The fiat currency code (EUR, USD, etc.)
     * @param timeoutDuration The timeout duration in seconds
     * @return escrowId The ID of the created escrow
     */
    function createProposal(
        address counterparty,
        address cryptoToken,
        uint256 cryptoAmount,
        uint256 fiatAmount,
        string calldata fiatCurrency,
        uint32 timeoutDuration
    ) external payable override nonReentrant whenNotPaused returns (uint256 escrowId) {
        require(counterparty != address(0), "P2PEscrow: invalid counterparty");
        require(counterparty != msg.sender, "P2PEscrow: cannot trade with yourself");
        require(supportedTokens[cryptoToken], "P2PEscrow: unsupported token");
        require(cryptoAmount > 0, "P2PEscrow: invalid crypto amount");
        require(fiatAmount > 0, "P2PEscrow: invalid fiat amount");
        require(bytes(fiatCurrency).length > 0, "P2PEscrow: empty fiat currency");
        require(timeoutDuration >= 3600 && timeoutDuration <= 2592000, "P2PEscrow: invalid timeout"); // 1 hour to 30 days
        
        // Check daily volume limits
        _checkDailyVolumeLimit(msg.sender, fiatAmount);
        
        // Check maximum escrow amount
        require(fiatAmount <= parameters[ParameterKeys.MAX_ESCROW_AMOUNT], "P2PEscrow: amount exceeds maximum");
        
        escrowId = escrowCount++;
        uint32 currentTime = uint32(block.timestamp);
        
        // Create the escrow
        Escrow storage newEscrow = escrows[escrowId];
        newEscrow.buyer = address(0); // Will be determined based on who initiated
        newEscrow.seller = address(0);
        newEscrow.initiator = msg.sender;
        newEscrow.cryptoToken = cryptoToken;
        newEscrow.cryptoAmount = cryptoAmount;
        newEscrow.fiatAmount = fiatAmount;
        newEscrow.fiatCurrency = fiatCurrency;
        newEscrow.timeoutDuration = timeoutDuration;
        newEscrow.createdAt = currentTime;
        newEscrow.expiresAt = currentTime + timeoutDuration;
        newEscrow.state = EscrowState.PROPOSED;
        newEscrow.funded = false;
        newEscrow.disputeId = 0;
        
        // Determine buyer and seller based on context
        // This is a simple proposal without immediate funding
        // The roles will be clarified when the proposal is accepted
        
        emit Events.ProposalCreated(escrowId, msg.sender, counterparty, cryptoToken, cryptoAmount, fiatAmount, fiatCurrency);
        
        return escrowId;
    }
    
    // ============ HELPER FUNCTIONS ============
    
    /**
     * @notice Check daily volume limits for a user
     * @param user The user to check
     * @param amount The transaction amount to add
     */
    function _checkDailyVolumeLimit(address user, uint256 amount) internal {
        uint256 today = block.timestamp / 86400; // Current day
        uint256 dailyLimit = parameters[ParameterKeys.DAILY_VOLUME_LIMIT];
        
        require(dailyVolume[user][today] + amount <= dailyLimit, "P2PEscrow: daily volume limit exceeded");
        
        dailyVolume[user][today] += amount;
    }
    
    /**
     * @notice Calculate fee for a transaction
     * @param fiatAmount The fiat amount in cents
     * @return The fee amount in crypto tokens
     */
    function _calculateFee(uint256 fiatAmount) internal view returns (uint256) {
        uint256 feePercentage = parameters[ParameterKeys.BASE_FEE_PERCENTAGE];
        uint256 minFeeUSD = parameters[ParameterKeys.MINIMUM_FEE_USD];
        uint256 maxFeeUSD = parameters[ParameterKeys.MAXIMUM_FEE_USD];
        
        // Calculate percentage-based fee
        uint256 percentageFee = (fiatAmount * feePercentage) / 10000; // feePercentage is in basis points
        
        // Apply minimum and maximum limits
        if (percentageFee < minFeeUSD) {
            percentageFee = minFeeUSD;
        } else if (percentageFee > maxFeeUSD) {
            percentageFee = maxFeeUSD;
        }
        
        // For simplicity, we assume 1:1 ratio between fiat and crypto for fee calculation
        // In a real implementation, you'd use an oracle for price conversion
        return percentageFee;
    }

    // ============ VIEW FUNCTIONS ============
    
    /**
     * @notice Get escrow data
     * @param escrowId The escrow ID
     * @return The escrow struct
     */
    function getEscrow(uint256 escrowId) external view override validEscrow(escrowId) returns (Escrow memory) {
        return escrows[escrowId];
    }
    
    /**
     * @notice Get dispute data
     * @param disputeId The dispute ID
     * @return The dispute struct
     */
    function getDispute(uint256 disputeId) external view override validDispute(disputeId) returns (Dispute memory) {
        return disputes[disputeId];
    }
    
    /**
     * @notice Get DAO balance available for withdrawal
     * @return The current DAO balance
     */
    function getDAOBalance() external view override returns (uint256) {
        return daoBalance;
    }
    
    /**
     * @notice Check if a proposal is still valid (not expired)
     * @param escrowId The escrow ID to check
     * @return True if the proposal is valid
     */
    function isProposalValid(uint256 escrowId) external view returns (bool) {
        if (escrowId >= escrowCount) return false;
        
        Escrow storage escrow = escrows[escrowId];
        return escrow.state == EscrowState.PROPOSED && block.timestamp <= escrow.expiresAt;
    }

    // ============ ADMIN FUNCTIONS ============
    
    /**
     * @notice Add a supported token
     * @param token The token address to add
     * @param decimals The number of decimals for the token
     */
    function addSupportedToken(address token, uint8 decimals) external override onlyDAO {
        require(token != address(0), "P2PEscrow: invalid token address");
        require(!supportedTokens[token], "P2PEscrow: token already supported");
        
        supportedTokens[token] = true;
        tokenDecimals[token] = decimals;
        
        // Get token symbol for event
        string memory symbol = "";
        try IERC20Extended(token).symbol() returns (string memory _symbol) {
            symbol = _symbol;
        } catch {
            symbol = "UNKNOWN";
        }
        
        emit Events.SupportedTokenAdded(token, symbol, decimals);
    }
    
    /**
     * @notice Update a parameter value
     * @param key The parameter key
     * @param value The new parameter value
     */
    function updateParameter(bytes32 key, uint256 value) external override onlyDAO {
        require(ParameterKeys.isValidEscrowParameter(key, value), "P2PEscrow: invalid parameter value");
        
        uint256 oldValue = parameters[key];
        parameters[key] = value;
        
        emit Events.ParameterUpdated("P2PEscrow", key, oldValue, value, msg.sender);
    }
    
    /**
     * @notice Pause the contract
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }
    
    /**
     * @notice Unpause the contract
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
    
    /**
     * @notice Get parameter value
     * @param key The parameter key
     * @return value The parameter value
     */
    function getParameter(bytes32 key) external view override returns (uint256) {
        return parameters[key];
    }
    
    /**
     * @notice Check if a token is supported
     * @param token The token address to check
     * @return supported True if the token is supported
     */
    function isTokenSupported(address token) external view override returns (bool) {
        return supportedTokens[token];
    }

    // ============ PLACEHOLDER FUNCTIONS ============
    // These will be implemented in subsequent tasks
    
    function createProposalWithFunding(
        address counterparty,
        address cryptoToken,
        uint256 cryptoAmount,
        uint256 fiatAmount,
        string calldata fiatCurrency,
        uint32 timeoutDuration
    ) external override nonReentrant whenNotPaused returns (uint256 escrowId) {
        require(counterparty != address(0), "P2PEscrow: invalid counterparty");
        require(counterparty != msg.sender, "P2PEscrow: cannot trade with yourself");
        require(supportedTokens[cryptoToken], "P2PEscrow: unsupported token");
        require(cryptoAmount > 0, "P2PEscrow: invalid crypto amount");
        require(fiatAmount > 0, "P2PEscrow: invalid fiat amount");
        require(bytes(fiatCurrency).length > 0, "P2PEscrow: empty fiat currency");
        require(timeoutDuration >= 3600 && timeoutDuration <= 2592000, "P2PEscrow: invalid timeout"); // 1 hour to 30 days
        
        // Check daily volume limits
        _checkDailyVolumeLimit(msg.sender, fiatAmount);
        
        // Check maximum escrow amount
        require(fiatAmount <= parameters[ParameterKeys.MAX_ESCROW_AMOUNT], "P2PEscrow: amount exceeds maximum");
        
        // Transfer crypto tokens to contract immediately
        IERC20 token = IERC20(cryptoToken);
        uint256 balanceBefore = token.balanceOf(address(this));
        
        token.safeTransferFrom(msg.sender, address(this), cryptoAmount);
        
        uint256 balanceAfter = token.balanceOf(address(this));
        require(balanceAfter - balanceBefore == cryptoAmount, "P2PEscrow: transfer amount mismatch");
        
        escrowId = escrowCount++;
        uint32 currentTime = uint32(block.timestamp);
        
        // Create the escrow with funding
        Escrow storage newEscrow = escrows[escrowId];
        newEscrow.buyer = counterparty;  // Counterparty will be the buyer (receives crypto)
        newEscrow.seller = msg.sender;   // Initiator is the seller (deposited crypto)
        newEscrow.initiator = msg.sender;
        newEscrow.cryptoToken = cryptoToken;
        newEscrow.cryptoAmount = cryptoAmount;
        newEscrow.fiatAmount = fiatAmount;
        newEscrow.fiatCurrency = fiatCurrency;
        newEscrow.timeoutDuration = timeoutDuration;
        newEscrow.createdAt = currentTime;
        newEscrow.fundedAt = currentTime;
        newEscrow.expiresAt = currentTime + timeoutDuration;
        newEscrow.state = EscrowState.PROPOSED;
        newEscrow.funded = true; // Already funded
        newEscrow.disputeId = 0;
        
        emit Events.ProposalCreated(escrowId, msg.sender, counterparty, cryptoToken, cryptoAmount, fiatAmount, fiatCurrency);
        emit Events.EscrowFunded(escrowId, msg.sender, cryptoAmount, cryptoToken);
        
        return escrowId;
    }
    
    function acceptProposal(uint256 escrowId) external override validEscrow(escrowId) nonReentrant whenNotPaused {
        Escrow storage escrow = escrows[escrowId];
        
        // Validate proposal state
        require(escrow.state == EscrowState.PROPOSED, "P2PEscrow: proposal not in proposed state");
        require(block.timestamp <= escrow.expiresAt, "P2PEscrow: proposal expired");
        
        // Determine buyer and seller roles based on who initiated and who is accepting
        address acceptor = msg.sender;
        require(acceptor != escrow.initiator, "P2PEscrow: initiator cannot accept own proposal");
        
        // In our design, we need to determine roles based on context
        // For simplicity, let's assume the initiator is always the seller (has the crypto)
        // and the acceptor is always the buyer (has the fiat)
        escrow.seller = escrow.initiator;
        escrow.buyer = acceptor;
        
        // Check if escrow was already funded (seller deposited when proposing)
        if (escrow.funded) {
            // If already funded, transition directly to FUNDED state
            escrow.state = EscrowState.FUNDED;
            escrow.fundedAt = uint32(block.timestamp);
            
            emit Events.ProposalAccepted(escrowId, acceptor, false);
            emit EscrowFunded(escrowId, escrow.seller, escrow.cryptoAmount, escrow.cryptoToken);
        } else {
            // If not funded, transition to ACCEPTED state - seller needs to fund
            escrow.state = EscrowState.ACCEPTED;
            emit Events.ProposalAccepted(escrowId, acceptor, false);
        }
        
        // Update daily volume for the buyer (who will be receiving the crypto)
        _checkDailyVolumeLimit(escrow.buyer, escrow.fiatAmount);
    }
    
    function acceptProposalWithFunding(uint256 escrowId) external override validEscrow(escrowId) nonReentrant whenNotPaused {
        Escrow storage escrow = escrows[escrowId];
        
        // Validate proposal state
        require(escrow.state == EscrowState.PROPOSED, "P2PEscrow: proposal not in proposed state");
        require(block.timestamp <= escrow.expiresAt, "P2PEscrow: proposal expired");
        require(!escrow.funded, "P2PEscrow: proposal already funded");
        
        address acceptor = msg.sender;
        require(acceptor != escrow.initiator, "P2PEscrow: initiator cannot accept own proposal");
        
        // Determine roles - acceptor becomes the seller (deposits crypto)
        escrow.buyer = escrow.initiator;  // Initiator becomes buyer
        escrow.seller = acceptor;         // Acceptor becomes seller
        
        // Transfer crypto tokens to contract
        IERC20 token = IERC20(escrow.cryptoToken);
        uint256 balanceBefore = token.balanceOf(address(this));
        
        token.safeTransferFrom(acceptor, address(this), escrow.cryptoAmount);
        
        uint256 balanceAfter = token.balanceOf(address(this));
        require(balanceAfter - balanceBefore == escrow.cryptoAmount, "P2PEscrow: transfer amount mismatch");
        
        // Update escrow state
        escrow.funded = true;
        escrow.state = EscrowState.FUNDED;
        escrow.fundedAt = uint32(block.timestamp);
        
        // Update daily volume tracking
        _checkDailyVolumeLimit(escrow.buyer, escrow.fiatAmount);
        
        emit Events.ProposalAccepted(escrowId, acceptor, true);
        emit EscrowFunded(escrowId, acceptor, escrow.cryptoAmount, escrow.cryptoToken);
    }
    
    function rejectProposal(uint256 escrowId, string calldata reason) external override validEscrow(escrowId) nonReentrant whenNotPaused {
        Escrow storage escrow = escrows[escrowId];
        
        // Validate proposal state and permissions
        require(
            escrow.state == EscrowState.PROPOSED || escrow.state == EscrowState.ACCEPTED,
            "P2PEscrow: invalid state for rejection"
        );
        require(bytes(reason).length > 0, "P2PEscrow: rejection reason required");
        
        // Only the non-initiator can reject a proposal
        require(msg.sender != escrow.initiator, "P2PEscrow: initiator cannot reject own proposal");
        
        // If proposal was funded, refund the funds
        if (escrow.funded) {
            IERC20 token = IERC20(escrow.cryptoToken);
            token.safeTransfer(escrow.initiator, escrow.cryptoAmount);
            
            emit Events.RefundExecuted(escrowId, escrow.initiator, escrow.cryptoAmount);
        }
        
        // Update state
        escrow.state = EscrowState.REJECTED;
        
        emit Events.ProposalRejected(escrowId, msg.sender, reason);
    }
    
    function cancelProposal(uint256 escrowId, string calldata reason) external override validEscrow(escrowId) nonReentrant whenNotPaused {
        Escrow storage escrow = escrows[escrowId];
        
        // Validate proposal state and permissions
        require(
            escrow.state == EscrowState.PROPOSED || escrow.state == EscrowState.ACCEPTED,
            "P2PEscrow: invalid state for cancellation"
        );
        require(bytes(reason).length > 0, "P2PEscrow: cancellation reason required");
        
        // Only the initiator can cancel their own proposal, or non-initiator if not yet accepted
        bool canCancel = (msg.sender == escrow.initiator) || 
                        (msg.sender != escrow.initiator && escrow.state == EscrowState.PROPOSED);
        require(canCancel, "P2PEscrow: not authorized to cancel");
        
        // If proposal was funded, refund the funds to whoever deposited them
        if (escrow.funded) {
            IERC20 token = IERC20(escrow.cryptoToken);
            // In case of seller-initiated proposal with funding, refund to initiator
            address refundRecipient = escrow.initiator;
            
            token.safeTransfer(refundRecipient, escrow.cryptoAmount);
            
            emit RefundExecuted(escrowId, refundRecipient, escrow.cryptoAmount);
        }
        
        // Update state
        escrow.state = EscrowState.CANCELLED;
        
        emit Events.ProposalCancelled(escrowId, msg.sender, reason);
    }
    
    function fundEscrow(uint256 escrowId) external override validEscrow(escrowId) nonReentrant whenNotPaused {
        Escrow storage escrow = escrows[escrowId];
        
        // Validate escrow state
        require(escrow.state == EscrowState.ACCEPTED, "P2PEscrow: escrow not in accepted state");
        require(!escrow.funded, "P2PEscrow: escrow already funded");
        require(block.timestamp <= escrow.expiresAt, "P2PEscrow: escrow expired");
        
        // Only the seller can fund the escrow
        require(msg.sender == escrow.seller, "P2PEscrow: only seller can fund escrow");
        
        // Transfer crypto tokens to contract
        IERC20 token = IERC20(escrow.cryptoToken);
        uint256 balanceBefore = token.balanceOf(address(this));
        
        token.safeTransferFrom(msg.sender, address(this), escrow.cryptoAmount);
        
        uint256 balanceAfter = token.balanceOf(address(this));
        require(balanceAfter - balanceBefore == escrow.cryptoAmount, "P2PEscrow: transfer amount mismatch");
        
        // Update escrow state
        escrow.funded = true;
        escrow.state = EscrowState.FUNDED;
        escrow.fundedAt = uint32(block.timestamp);
        
        emit EscrowFunded(escrowId, msg.sender, escrow.cryptoAmount, escrow.cryptoToken);
    }
    
    function completeTransaction(uint256 escrowId) external override validEscrow(escrowId) nonReentrant whenNotPaused {
        Escrow storage escrow = escrows[escrowId];
        
        // Validate escrow state
        require(escrow.state == EscrowState.FUNDED, "P2PEscrow: escrow not funded");
        require(escrow.funded, "P2PEscrow: no funds available");
        
        // Only the seller can complete the transaction (confirming fiat receipt)
        require(msg.sender == escrow.seller, "P2PEscrow: only seller can complete transaction");
        
        // Calculate fee
        uint256 feeAmount = _calculateFee(escrow.fiatAmount);
        uint256 transferAmount = escrow.cryptoAmount - feeAmount;
        
        // Transfer tokens to buyer and fee to DAO
        IERC20 token = IERC20(escrow.cryptoToken);
        
        if (transferAmount > 0) {
            token.safeTransfer(escrow.buyer, transferAmount);
        }
        
        if (feeAmount > 0) {
            // Keep fee in contract for DAO collection
            daoBalance += feeAmount;
            totalFeesCollected += feeAmount;
            
            // Update daily revenue tracking
            uint256 today = block.timestamp / 86400;

        }
        
        // Update escrow state
        escrow.state = EscrowState.COMPLETED;
        
        emit Events.TransactionCompleted(escrowId, escrow.buyer, escrow.seller, escrow.cryptoAmount, feeAmount);
    }
    
    function requestRefund(uint256 escrowId) external override validEscrow(escrowId) nonReentrant whenNotPaused {
        Escrow storage escrow = escrows[escrowId];
        
        // Validate escrow state
        require(escrow.state == EscrowState.FUNDED, "P2PEscrow: escrow not funded");
        require(escrow.funded, "P2PEscrow: no funds available");
        
        // Only the seller can request refund
        require(msg.sender == escrow.seller, "P2PEscrow: only seller can request refund");
        
        // Set refund timeout period
        uint256 refundTimeout = parameters[ParameterKeys.DISPUTE_TIME_WINDOW];
        uint32 timeoutEndsAt = uint32(block.timestamp + refundTimeout);
        
        // Update escrow state
        escrow.state = EscrowState.TO_REFUND_TIMEOUT;
        escrow.expiresAt = timeoutEndsAt; // Reuse expiresAt for timeout tracking
        
        emit Events.RefundRequested(escrowId, msg.sender, escrow.expiresAt);
    }
    
    function executeRefund(uint256 escrowId) external override validEscrow(escrowId) nonReentrant whenNotPaused {
        Escrow storage escrow = escrows[escrowId];
        
        // Validate escrow state
        require(escrow.state == EscrowState.TO_REFUND_TIMEOUT, "P2PEscrow: escrow not in refund timeout");
        require(escrow.funded, "P2PEscrow: no funds available");
        
        // Only the seller can execute refund
        require(msg.sender == escrow.seller, "P2PEscrow: only seller can execute refund");
        
        // Check that timeout period has passed
        require(block.timestamp >= escrow.expiresAt, "P2PEscrow: refund timeout not yet expired");
        
        // Transfer funds back to seller
        IERC20 token = IERC20(escrow.cryptoToken);
        token.safeTransfer(escrow.seller, escrow.cryptoAmount);
        
        // Update escrow state
        escrow.funded = false;
        escrow.state = EscrowState.CANCELLED;
        
        emit Events.RefundExecuted(escrowId, escrow.seller, escrow.cryptoAmount);
    }
    
    function raiseDispute(uint256 escrowId, string calldata evidence) external override validEscrow(escrowId) nonReentrant whenNotPaused returns (uint256 disputeId) {
        Escrow storage escrow = escrows[escrowId];
        
        // Validate escrow state - disputes can be raised from FUNDED or TO_REFUND_TIMEOUT states
        require(
            escrow.state == EscrowState.FUNDED || escrow.state == EscrowState.TO_REFUND_TIMEOUT,
            "P2PEscrow: invalid state for dispute"
        );
        require(escrow.funded, "P2PEscrow: no funds to dispute");
        require(bytes(evidence).length > 0, "P2PEscrow: evidence required");
        
        // Only participants can raise disputes
        require(
            msg.sender == escrow.buyer || msg.sender == escrow.seller,
            "P2PEscrow: only participants can raise disputes"
        );
        
        // Create new dispute
        disputeId = disputeCount++;
        uint32 currentTime = uint32(block.timestamp);
        
        Dispute storage newDispute = disputes[disputeId];
        newDispute.escrowId = escrowId;
        newDispute.initiator = msg.sender;
        newDispute.arbitrator = address(0); // Will be assigned later
        newDispute.createdAt = currentTime;
        newDispute.evidenceDeadline = currentTime + uint32(parameters[ParameterKeys.EVIDENCE_SUBMISSION_TIME]);
        newDispute.resolutionDeadline = currentTime + uint32(parameters[ParameterKeys.ARBITRATOR_RESPONSE_TIME]);
        newDispute.resolved = false;
        newDispute.buyerWins = false;
        
        // Set evidence based on who initiated
        if (msg.sender == escrow.buyer) {
            newDispute.buyerEvidence = evidence;
            newDispute.sellerEvidence = "";
        } else {
            newDispute.sellerEvidence = evidence;
            newDispute.buyerEvidence = "";
        }
        
        // Update escrow state and link dispute
        escrow.state = EscrowState.DISPUTED;
        escrow.disputeId = disputeId;
        
        emit Events.DisputeRaised(escrowId, disputeId, msg.sender, evidence);
        
        return disputeId;
    }
    
    function submitEvidence(uint256 disputeId, string calldata evidence) external override validDispute(disputeId) nonReentrant whenNotPaused {
        Dispute storage dispute = disputes[disputeId];
        Escrow storage escrow = escrows[dispute.escrowId];
        
        // Validate dispute state
        require(!dispute.resolved, "P2PEscrow: dispute already resolved");
        require(block.timestamp <= dispute.evidenceDeadline, "P2PEscrow: evidence deadline passed");
        require(bytes(evidence).length > 0, "P2PEscrow: evidence required");
        
        // Only participants can submit evidence
        require(
            msg.sender == escrow.buyer || msg.sender == escrow.seller,
            "P2PEscrow: only participants can submit evidence"
        );
        
        // Update evidence based on who is submitting
        if (msg.sender == escrow.buyer) {
            dispute.buyerEvidence = evidence;
        } else {
            dispute.sellerEvidence = evidence;
        }
        
        emit Events.EvidenceSubmitted(disputeId, msg.sender, evidence);
    }
    
    function resolveDispute(uint256 disputeId, bool buyerWins, string calldata notes) external override validDispute(disputeId) onlyArbitrator nonReentrant whenNotPaused {
        Dispute storage dispute = disputes[disputeId];
        Escrow storage escrow = escrows[dispute.escrowId];
        
        // Validate dispute state
        require(!dispute.resolved, "P2PEscrow: dispute already resolved");
        require(dispute.arbitrator == msg.sender, "P2PEscrow: not assigned arbitrator");
        require(escrow.state == EscrowState.DISPUTED, "P2PEscrow: escrow not in disputed state");
        require(escrow.funded, "P2PEscrow: no funds to distribute");
        
        // Calculate arbitration fee
        uint256 arbitrationFee = parameters[ParameterKeys.ARBITRATION_FEE];
        uint256 availableFunds = escrow.cryptoAmount;
        
        require(availableFunds > arbitrationFee, "P2PEscrow: insufficient funds for arbitration fee");
        
        // Resolve dispute
        dispute.resolved = true;
        dispute.buyerWins = buyerWins;
        dispute.arbitratorNotes = notes;
        
        // Distribute funds
        IERC20 token = IERC20(escrow.cryptoToken);
        uint256 remainingFunds = availableFunds - arbitrationFee;
        
        if (buyerWins) {
            // Buyer wins: gets the crypto minus arbitration fee
            token.safeTransfer(escrow.buyer, remainingFunds);
        } else {
            // Seller wins: gets refund minus arbitration fee
            token.safeTransfer(escrow.seller, remainingFunds);
        }
        
        // Pay arbitration fee to arbitrator (simplified - in reality might go to DAO)
        token.safeTransfer(msg.sender, arbitrationFee);
        
        // Update escrow state
        escrow.funded = false;
        escrow.state = EscrowState.COMPLETED;
        
        emit Events.DisputeResolved(disputeId, dispute.escrowId, msg.sender, buyerWins, escrow.cryptoAmount);
    }
    
    function assignArbitrator(uint256 disputeId, address arbitrator) external override validDispute(disputeId) onlyDAO nonReentrant {
        Dispute storage dispute = disputes[disputeId];
        
        // Validate dispute state
        require(!dispute.resolved, "P2PEscrow: dispute already resolved");
        require(dispute.arbitrator == address(0), "P2PEscrow: arbitrator already assigned");
        require(authorizedArbitrators[arbitrator], "P2PEscrow: arbitrator not authorized");
        
        // Assign arbitrator
        dispute.arbitrator = arbitrator;
        
        emit Events.ArbitratorAssigned(disputeId, arbitrator);
    }
    
    function addAuthorizedArbitrator(address arbitrator, uint256 stakeRequired) external override onlyDAO {
        require(arbitrator != address(0), "P2PEscrow: invalid arbitrator address");
        require(!authorizedArbitrators[arbitrator], "P2PEscrow: arbitrator already authorized");
        require(stakeRequired > 0, "P2PEscrow: stake required must be positive");
        
        // Add arbitrator
        authorizedArbitrators[arbitrator] = true;
        arbitratorStakes[arbitrator] = stakeRequired;
        
        // Grant arbitrator role
        _grantRole(ARBITRATOR_ROLE, arbitrator);
        
        emit Events.ArbitratorAdded(arbitrator, stakeRequired, msg.sender);
    }
    
    function removeAuthorizedArbitrator(address arbitrator) external override onlyDAO {
        require(arbitrator != address(0), "P2PEscrow: invalid arbitrator address");
        require(authorizedArbitrators[arbitrator], "P2PEscrow: arbitrator not authorized");
        
        // Remove arbitrator
        authorizedArbitrators[arbitrator] = false;
        arbitratorStakes[arbitrator] = 0;
        
        // Revoke arbitrator role
        _revokeRole(ARBITRATOR_ROLE, arbitrator);
        
        emit Events.ArbitratorRemoved(arbitrator, msg.sender, "Removed by DAO");
    }
    
    function withdrawDAOFunds(uint256 amount, address token) external override onlyDAO {
        require(amount > 0, "P2PEscrow: invalid amount");
        require(amount <= daoBalance, "P2PEscrow: insufficient DAO balance");
        require(supportedTokens[token], "P2PEscrow: unsupported token");
        
        // Reduce DAO balance
        daoBalance -= amount;
        
        // Transfer to DAO
        IERC20(token).safeTransfer(msg.sender, amount);
    }
}