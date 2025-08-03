// SPDX-License-Identifier: ISC
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockERC20
 * @notice Mock ERC20 token for testing
 */
contract MockERC20 is ERC20, Ownable {
    uint8 private _decimals;

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals_,
        uint256 initialSupply
    ) ERC20(name, symbol) Ownable(msg.sender) {
        _decimals = decimals_;
        _mint(msg.sender, initialSupply);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }

    // Add some test utilities
    function faucet(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title MockArbitrator
 * @notice Mock arbitrator for testing dispute resolution
 */
contract MockArbitrator {
    mapping(uint256 => bool) public disputeResolutions;
    
    event DisputeResolved(uint256 indexed disputeId, bool buyerWins);

    function resolveDispute(uint256 disputeId, bool buyerWins) external {
        disputeResolutions[disputeId] = buyerWins;
        emit DisputeResolved(disputeId, buyerWins);
    }

    function getDisputeResolution(uint256 disputeId) external view returns (bool) {
        return disputeResolutions[disputeId];
    }
}

/**
 * @title MockTimeManipulator
 * @notice Helper contract for time-based testing
 */
contract MockTimeManipulator {
    uint256 private _currentTime;
    bool private _useCustomTime;

    constructor() {
        _currentTime = block.timestamp;
        _useCustomTime = false;
    }

    function setCustomTime(uint256 timestamp) external {
        _currentTime = timestamp;
        _useCustomTime = true;
    }

    function increaseTime(uint256 seconds_) external {
        _currentTime += seconds_;
        _useCustomTime = true;
    }

    function getCurrentTime() external view returns (uint256) {
        return _useCustomTime ? _currentTime : block.timestamp;
    }

    function resetTime() external {
        _useCustomTime = false;
    }
}

/**
 * @title MockPlatform
 * @notice Mock platform contract for reputation testing
 */
contract MockPlatform {
    string public name;
    address public owner;

    constructor(string memory _name) {
        name = _name;
        owner = msg.sender;
    }

    function getName() external view returns (string memory) {
        return name;
    }

    function getOwner() external view returns (address) {
        return owner;
    }
}

/**
 * @title TestEventLogger
 * @notice Helper contract to test event emissions
 */
contract TestEventLogger {
    event TestEvent(string indexed eventType, uint256 indexed value, bytes data);

    function logEvent(string calldata eventType, uint256 value, bytes calldata data) external {
        emit TestEvent(eventType, value, data);
    }
}