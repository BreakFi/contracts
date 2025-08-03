// SPDX-License-Identifier: ISC
pragma solidity ^0.8.20;

/**
 * @title IPlatformDAO
 * @notice Interface for the Platform DAO contract
 * @dev Multi-sig contract for parameter management and revenue collection
 */
interface IPlatformDAO {
    /// @notice Multi-sig transaction structure
    struct Transaction {
        address to;                 // Target address
        uint256 value;             // ETH value
        bytes data;                // Call data
        bool executed;             // Execution status
        uint256 signatureCount;    // Number of signatures
        uint32 createdAt;         // Creation timestamp
    }

    /// @notice Revenue tracking structure
    struct RevenueData {
        uint256 escrowFees;        // Escrow revenue
        uint256 reputationFees;    // Reputation revenue
        uint256 timestamp;         // Recording timestamp
    }

    // Events
    event TransactionSubmitted(uint256 indexed txId, address indexed submitter, address to, uint256 value, string description);
    event TransactionSigned(uint256 indexed txId, address indexed signer);
    event TransactionExecuted(uint256 indexed txId);
    event SignerAdded(address indexed signer);
    event SignerRemoved(address indexed signer);
    event RequiredSignaturesChanged(uint256 oldRequired, uint256 newRequired);
    event ParameterUpdated(string indexed contractType, bytes32 indexed parameter, uint256 oldValue, uint256 newValue);
    event RevenueCollected(address indexed source, uint256 amount, uint256 timestamp);
    event RevenueWithdrawn(address indexed recipient, uint256 amount, string purpose);
    event ArbitratorAdded(address indexed arbitrator, uint256 stakeRequired);
    event ArbitratorRemoved(address indexed arbitrator);
    event ContractApproved(address indexed contractAddr, uint32 weight, string name);
    event ContractRevoked(address indexed contractAddr, string reason);


    // Multi-Sig Management Functions
    function submitTransaction(address to, uint256 value, bytes calldata data, string calldata description) external returns (uint256 txId);
    function signTransaction(uint256 txId) external;
    function executeTransaction(uint256 txId) external;
    function addSigner(address newSigner) external;
    function removeSigner(address signer) external;
    function changeRequiredSignatures(uint256 newRequired) external;

    // Revenue Collection Functions
    function collectEscrowRevenue() external;
    function collectReputationRevenue() external;
    function collectAllRevenue() external;
    function withdrawFunds(address recipient, uint256 amount, string calldata purpose) external;
    function emergencyWithdraw(address recipient) external;
    function getTreasuryBalance() external view returns (uint256);

    // Parameter Management Functions (Escrow)
    function setEscrowParameter(bytes32 parameterKey, uint256 value) external;
    function batchUpdateEscrowParameters(bytes32[] calldata keys, uint256[] calldata values) external;

    // Parameter Management Functions (Reputation)
    function setReputationParameter(bytes32 parameterKey, uint256 value) external;
    function batchUpdateReputationParameters(bytes32[] calldata keys, uint256[] calldata values) external;

    // Contract Management Functions
    function addArbitrator(address arbitrator, uint256 stakeRequired) external;
    function removeArbitrator(address arbitrator) external;
    function approveReputationContract(address contractAddr, uint32 weight, string calldata name) external;
    function revokeReputationContract(address contractAddr, string calldata reason) external;

    // Revenue Functions
    function getTotalRevenue() external view returns (uint256);

    // Additional View Functions
    function getTransaction(uint256 txId) external view returns (
        address to,
        uint256 value,
        bytes memory data,
        bool executed,
        uint256 signatureCount,
        string memory description
    );
    function hasSignedTransaction(uint256 txId, address signer) external view returns (bool);
    function getSigners() external view returns (address[] memory);
    function getParameter(bytes32 key) external view returns (uint256);

    // Public storage getters (automatically generated)
    function signers(uint256 index) external view returns (address);
    function requiredSignatures() external view returns (uint256);
    function isSigner(address account) external view returns (bool);
    function transactionCount() external view returns (uint256);
    function parameters(bytes32 key) external view returns (uint256);
    function parameterExists(bytes32 key) external view returns (bool);
    function totalRevenueCollected() external view returns (uint256);
    function lastCollectionTimestamp() external view returns (uint256);
    // Note: dailyRevenue is a public array with automatic getter

}