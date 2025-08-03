// SPDX-License-Identifier: ISC
pragma solidity ^0.8.20;

/**
 * @title EventTypes
 * @notice Library defining standardized event types for reputation system
 * @dev Contains constants for all supported reputation event types
 */
library EventTypes {
    // Trading Events
    bytes32 constant TRADE_COMPLETED = keccak256("trade_completed");
    bytes32 constant TRADE_CANCELLED = keccak256("trade_cancelled");
    bytes32 constant TRADE_DISPUTED = keccak256("trade_disputed");
    
    // Dispute Resolution Events
    bytes32 constant DISPUTE_WON = keccak256("dispute_won");
    bytes32 constant DISPUTE_LOST = keccak256("dispute_lost");
    bytes32 constant DISPUTE_RESOLVED_FAVORABLY = keccak256("dispute_resolved_favorably");
    bytes32 constant DISPUTE_RESOLVED_UNFAVORABLY = keccak256("dispute_resolved_unfavorably");
    
    // Lending/DeFi Events
    bytes32 constant LOAN_REPAID = keccak256("loan_repaid");
    bytes32 constant LOAN_DEFAULTED = keccak256("loan_defaulted");
    bytes32 constant LOAN_EXTENDED = keccak256("loan_extended");
    bytes32 constant COLLATERAL_LIQUIDATED = keccak256("collateral_liquidated");
    
    // Trading/Swap Events
    bytes32 constant SWAP_COMPLETED = keccak256("swap_completed");
    bytes32 constant SWAP_FAILED = keccak256("swap_failed");
    bytes32 constant LIQUIDITY_PROVIDED = keccak256("liquidity_provided");
    bytes32 constant LIQUIDITY_REMOVED = keccak256("liquidity_removed");
    
    // Service Events
    bytes32 constant SERVICE_COMPLETED = keccak256("service_completed");
    bytes32 constant SERVICE_CANCELLED = keccak256("service_cancelled");
    bytes32 constant SERVICE_DISPUTED = keccak256("service_disputed");
    bytes32 constant SERVICE_RATED = keccak256("service_rated");
    
    // Verification Events
    bytes32 constant KYC_VERIFIED = keccak256("kyc_verified");
    bytes32 constant KYC_REVOKED = keccak256("kyc_revoked");
    bytes32 constant IDENTITY_VERIFIED = keccak256("identity_verified");
    bytes32 constant IDENTITY_DISPUTED = keccak256("identity_disputed");
    bytes32 constant ADDRESS_VERIFIED = keccak256("address_verified");
    bytes32 constant PHONE_VERIFIED = keccak256("phone_verified");
    bytes32 constant EMAIL_VERIFIED = keccak256("email_verified");
    
    // Governance Events
    bytes32 constant PROPOSAL_CREATED = keccak256("proposal_created");
    bytes32 constant PROPOSAL_VOTED = keccak256("proposal_voted");
    bytes32 constant PROPOSAL_EXECUTED = keccak256("proposal_executed");
    bytes32 constant DELEGATION_MADE = keccak256("delegation_made");
    
    // Staking Events
    bytes32 constant STAKE_DEPOSITED = keccak256("stake_deposited");
    bytes32 constant STAKE_WITHDRAWN = keccak256("stake_withdrawn");
    bytes32 constant REWARDS_CLAIMED = keccak256("rewards_claimed");
    bytes32 constant SLASH_OCCURRED = keccak256("slash_occurred");
    
    // Arbitration Events
    bytes32 constant ARBITRATION_ACCEPTED = keccak256("arbitration_accepted");
    bytes32 constant ARBITRATION_RESOLVED = keccak256("arbitration_resolved");
    bytes32 constant ARBITRATION_APPEALED = keccak256("arbitration_appealed");
    
    // Negative Events (reputation penalties)
    bytes32 constant SCAM_REPORTED = keccak256("scam_reported");
    bytes32 constant FRAUD_DETECTED = keccak256("fraud_detected");
    bytes32 constant MALICIOUS_BEHAVIOR = keccak256("malicious_behavior");
    bytes32 constant SPAM_ACTIVITY = keccak256("spam_activity");
    bytes32 constant TERMS_VIOLATED = keccak256("terms_violated");
    
    // Platform-Specific Events
    bytes32 constant REFERRAL_MADE = keccak256("referral_made");
    bytes32 constant MILESTONE_ACHIEVED = keccak256("milestone_achieved");
    bytes32 constant BADGE_EARNED = keccak256("badge_earned");
    bytes32 constant LEVEL_UPGRADED = keccak256("level_upgraded");
    bytes32 constant PREMIUM_ACTIVATED = keccak256("premium_activated");

}