import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, network } = hre;
  const { get } = deployments;
  const { deployer, dao } = await getNamedAccounts();

  console.log(`Configuring system on ${network.name}...`);

  // Get deployed contract addresses
  const escrowDeployment = await get("P2PEscrow");
  const reputationDeployment = await get("ReputationRegistry");
  const daoDeployment = await get("PlatformDAO");

  // Get contract instances
  const escrow = await ethers.getContractAt("P2PEscrow", escrowDeployment.address);
  const reputation = await ethers.getContractAt("ReputationRegistry", reputationDeployment.address);
  const platformDAO = await ethers.getContractAt("PlatformDAO", daoDeployment.address);

  console.log("Setting up initial configuration...");

  // Configure supported tokens for escrow
  const supportedTokens = getSupportedTokensForNetwork(network.name);
  
  for (const token of supportedTokens) {
    try {
      console.log(`Adding supported token: ${token.symbol} at ${token.address}`);
      const tx = await escrow.addSupportedToken(token.address, token.symbol, token.decimals);
      await tx.wait();
      console.log(`✅ Added ${token.symbol} as supported token`);
    } catch (error) {
      console.log(`⚠️  Failed to add ${token.symbol}:`, error);
    }
  }

  // Set default parameters for escrow contract
  console.log("Setting default escrow parameters...");
  const escrowParams = getDefaultEscrowParameters();
  
  for (const [key, value] of Object.entries(escrowParams)) {
    try {
      const paramKey = ethers.keccak256(ethers.toUtf8Bytes(key));
      const tx = await escrow.updateParameter(paramKey, value);
      await tx.wait();
      console.log(`✅ Set parameter ${key} = ${value}`);
    } catch (error) {
      console.log(`⚠️  Failed to set parameter ${key}:`, error);
    }
  }

  // Set default parameters for reputation registry
  console.log("Setting default reputation parameters...");
  const reputationParams = getDefaultReputationParameters();
  
  for (const [key, value] of Object.entries(reputationParams)) {
    try {
      const paramKey = ethers.keccak256(ethers.toUtf8Bytes(key));
      const tx = await reputation.updateParameter(paramKey, value);
      await tx.wait();
      console.log(`✅ Set reputation parameter ${key} = ${value}`);
    } catch (error) {
      console.log(`⚠️  Failed to set reputation parameter ${key}:`, error);
    }
  }

  // Transfer ownership from deployer to DAO if needed
  console.log("Configuring contract ownership...");
  
  try {
    // Grant DAO role to the actual DAO contract
    if ((await escrow.hasRole(await escrow.DAO_ROLE(), daoDeployment.address)) === false) {
      const tx = await escrow.grantRole(await escrow.DAO_ROLE(), daoDeployment.address);
      await tx.wait();
      console.log("✅ Granted DAO role to Platform DAO contract for Escrow");
    }
    
    if ((await reputation.hasRole(await reputation.DAO_ROLE(), daoDeployment.address)) === false) {
      const tx = await reputation.grantRole(await reputation.DAO_ROLE(), daoDeployment.address);
      await tx.wait();
      console.log("✅ Granted DAO role to Platform DAO contract for Reputation");
    }
  } catch (error) {
    console.log("⚠️  Failed to configure contract ownership:", error);
  }

  console.log("✅ System configuration completed!");
  
  // Log final configuration summary
  console.log("\n📋 DEPLOYMENT SUMMARY");
  console.log("====================");
  console.log(`P2P Escrow:         ${escrowDeployment.address}`);
  console.log(`Reputation Registry: ${reputationDeployment.address}`);
  console.log(`Platform DAO:       ${daoDeployment.address}`);
  console.log(`Network:            ${network.name}`);
  console.log(`Supported Tokens:   ${supportedTokens.length}`);

  return true;
};

function getSupportedTokensForNetwork(networkName: string) {
  switch (networkName) {
    case "mainnet":
      return [
        { address: "0xA0b86a33E6441C8BB6f7d0E9c07fcb5b22E5EbD7", symbol: "USDC", decimals: 6 },
        { address: "0xdAC17F958D2ee523a2206206994597C13D831ec7", symbol: "USDT", decimals: 6 },
        { address: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", symbol: "WETH", decimals: 18 },
      ];
    case "polygon":
      return [
        { address: "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", symbol: "USDC", decimals: 6 },
        { address: "0xc2132D05D31c914a87C6611C10748AEb04B58e8F", symbol: "USDT", decimals: 6 },
        { address: "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619", symbol: "WETH", decimals: 18 },
      ];
    case "arbitrum":
      return [
        { address: "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8", symbol: "USDC", decimals: 6 },
        { address: "0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9", symbol: "USDT", decimals: 6 },
        { address: "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1", symbol: "WETH", decimals: 18 },
      ];
    default:
      // For testnets/local, return empty array (tokens will be added separately)
      return [];
  }
}

function getDefaultEscrowParameters() {
  return {
    "BASE_FEE_PERCENTAGE": 150, // 1.5%
    "MIN_FEE_USD_CENTS": 500, // $5.00
    "MAX_FEE_USD_CENTS": 10000, // $100.00
    "KYC_REQUIRED_ABOVE": 500000, // $5,000 in cents
    "DAILY_VOLUME_LIMIT": 5000000, // $50,000 in cents
    "MAX_ESCROW_AMOUNT": 10000000, // $100,000 in cents
    "DISPUTE_TIME_WINDOW": 86400, // 24 hours
    "EVIDENCE_SUBMISSION_WINDOW": 259200, // 72 hours
    "ARBITRATOR_RESPONSE_TIMEOUT": 604800, // 7 days
    "REFUND_TIMEOUT": 259200, // 72 hours
  };
}

function getDefaultReputationParameters() {
  return {
    "PREPAID_SUBMISSION_FEE": 1000000, // $1 in USDC wei (6 decimals)
    "MIN_PREPAID_DEPOSIT": 100000000, // $100 in USDC wei
    "SUBMISSION_DELAY": 3600, // 1 hour
    "MAX_BATCH_SIZE": 100,
    "EVENT_EXPIRY_DAYS": 365, // 1 year
  };
}

func.tags = ["configure", "setup"];
func.id = "configure_system";
func.dependencies = ["P2PEscrow", "ReputationRegistry", "PlatformDAO"];

export default func;