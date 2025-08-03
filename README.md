# Smart Contracts - P2P Escrow, Reputation Registry & Platform DAO

![CI](https://github.com/BreakFi/contracts/actions/workflows/ci.yml/badge.svg)
[![codecov](https://codecov.io/gh/BreakFi/contracts/branch/main/graph/badge.svg)](https://codecov.io/gh/BreakFi/contracts)

A comprehensive smart contract system implementing three interconnected contracts for decentralized P2P trading with reputation management and DAO governance.

## 🏗️ Architecture

### Core Contracts

1. **P2P Escrow Contract** - Handles peer-to-peer trading with mutual consent
2. **Reputation Registry Contract** - Manages cross-platform reputation data
3. **Platform DAO Contract** - Controls parameters and collects revenue

### Key Features

- ✅ Bidirectional P2P escrow with flexible proposal creation
- ✅ Cross-platform reputation tracking with two-tier authorization
- ✅ Multi-sig DAO for parameter management and revenue collection
- ✅ Comprehensive dispute resolution system
- ✅ Gas-optimized storage and batch operations
- ✅ Multi-chain deployment support

## 🚀 Quick Start

### Prerequisites

- Node.js 18+
- npm or yarn

### Installation

```bash
npm install
cp .env.example .env
# Fill in your environment variables
```

### Development

```bash
# Compile contracts
npm run build

# Run tests
npm run test

# Run tests with gas reporting
npm run test:gas

# Run coverage
npm run test:coverage

# Lint contracts
npm run lint

# Format code
npm run format
```

### Deployment

```bash
# Deploy to localhost
npm run deploy:localhost

# Deploy to testnet
npm run deploy:goerli
npm run deploy:mumbai

# Deploy to mainnet
npm run deploy:mainnet
npm run deploy:polygon
npm run deploy:arbitrum
```

## 📋 Development Status

- ✅ Project Setup & Infrastructure
- 🔄 Interface Definitions (In Progress)
- ⏳ P2P Escrow Contract Implementation
- ⏳ Reputation Registry Contract Implementation
- ⏳ Platform DAO Contract Implementation
- ⏳ Testing Suite
- ⏳ Deployment Scripts
- ⏳ Documentation

## 🧪 Testing

The project includes comprehensive testing:

- **Unit Tests**: Individual contract function testing
- **Integration Tests**: Cross-contract interaction testing
- **Security Tests**: Attack vector and edge case testing
- **Gas Optimization Tests**: Gas usage analysis

## 🔒 Security

- OpenZeppelin security patterns
- Reentrancy protection
- Access control mechanisms
- Parameter validation
- Emergency pause functionality

## 📊 Gas Optimization

- Packed structs for storage efficiency
- Batch operations for multiple transactions
- Optimized mappings and data structures
- Gas usage monitoring and reporting

## 🌐 Multi-Chain Support

- Ethereum Mainnet
- Polygon
- Arbitrum
- Testnets: Goerli, Mumbai

## 📖 Documentation

- [P2P Escrow Specification](./escrow.md)
- [Reputation Registry Specification](./reputation.md)
- [Platform DAO Specification](./dao.md)
- [Technical Specification](./contracts.spec)
- [Implementation Tasks](./contracts.tasks.md)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes with tests
4. Ensure linting and formatting pass
5. Submit a pull request

## 📄 License

This project is licensed under the ISC License - see the [LICENSE](LICENSE) file for details.

## 🔗 Links

- [GitHub Repository](https://github.com/BreakFi/contracts)
- [Documentation](./docs/)
- [Issue Tracker](https://github.com/BreakFi/contracts/issues)