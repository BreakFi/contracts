import { ethers } from "hardhat";
import hre from "hardhat";

/**
 * Script to deploy the full system on testnets (Goerli, Mumbai, etc.)
 */
async function main() {
  const networkName = hre.network.name;
  console.log(`🚀 Deploying complete system on ${networkName} testnet...\n`);

  const [deployer] = await ethers.getSigners();
  
  console.log("📋 Deployment Account:");
  console.log(`Deployer: ${deployer.address}`);
  console.log(`Balance: ${ethers.formatEther(await deployer.provider.getBalance(deployer.address))} ETH\n`);

  // Configuration based on network
  const config = getNetworkConfig(networkName);
  if (!config) {
    throw new Error(`Unsupported network: ${networkName}`);
  }

  console.log(`📍 Network: ${networkName}`);
  console.log(`🏛️  DAO Address: ${config.daoAddress}`);
  console.log(`💰 USDC Address: ${config.usdcAddress}\n`);

  // Deploy P2P Escrow
  console.log("🔒 Deploying P2P Escrow...");
  const P2PEscrow = await ethers.getContractFactory("P2PEscrow");
  const escrow = await P2PEscrow.deploy(config.daoAddress);
  await escrow.waitForDeployment();
  const escrowAddress = await escrow.getAddress();
  console.log(`P2P Escrow deployed at: ${escrowAddress}`);
  
  // Wait for confirmations
  console.log("⏳ Waiting for confirmations...");
  await new Promise(resolve => setTimeout(resolve, 30000));

  // Deploy Reputation Registry
  console.log("\n⭐ Deploying Reputation Registry...");
  const ReputationRegistry = await ethers.getContractFactory("ReputationRegistry");
  const reputation = await ReputationRegistry.deploy(config.daoAddress, config.usdcAddress);
  await reputation.waitForDeployment();
  const reputationAddress = await reputation.getAddress();
  console.log(`Reputation Registry deployed at: ${reputationAddress}`);

  // Wait for confirmations
  console.log("⏳ Waiting for confirmations...");
  await new Promise(resolve => setTimeout(resolve, 30000));

  // Deploy Platform DAO
  console.log("\n🏛️  Deploying Platform DAO...");
  const PlatformDAO = await ethers.getContractFactory("PlatformDAO");
  
  const platformDAO = await PlatformDAO.deploy(
    config.initialSigners,
    config.requiredSignatures,
    escrowAddress,
    reputationAddress
  );
  await platformDAO.waitForDeployment();
  const platformDAOAddress = await platformDAO.getAddress();
  console.log(`Platform DAO deployed at: ${platformDAOAddress}`);

  console.log("\n🎉 Testnet deployment completed!");
  console.log("\n📋 CONTRACT ADDRESSES:");
  console.log("=====================");
  console.log(`P2P Escrow:          ${escrowAddress}`);
  console.log(`Reputation Registry: ${reputationAddress}`);
  console.log(`Platform DAO:        ${platformDAOAddress}`);
  console.log(`Network:             ${networkName}`);
  
  console.log("\n🔍 CONTRACT VERIFICATION:");
  console.log("=========================");
  console.log("Run the following commands to verify contracts:");
  console.log(`npx hardhat verify --network ${networkName} ${escrowAddress} "${config.daoAddress}"`);
  console.log(`npx hardhat verify --network ${networkName} ${reputationAddress} "${config.daoAddress}" "${config.usdcAddress}"`);
  console.log(`npx hardhat verify --network ${networkName} ${platformDAOAddress} [${config.initialSigners.map(s => `"${s}"`).join(',')}] ${config.requiredSignatures} "${escrowAddress}" "${reputationAddress}"`);

  console.log("\n💡 NEXT STEPS:");
  console.log("==============");
  console.log("1. Verify contracts on block explorer");
  console.log("2. Configure initial parameters");
  console.log("3. Add supported tokens");
  console.log("4. Set up arbitrators");
  console.log("5. Test the system functionality");
}

function getNetworkConfig(networkName: string) {
  switch (networkName) {
    case "goerli":
      return {
        daoAddress: "0x1234567890123456789012345678901234567890", // Replace with actual DAO address
        usdcAddress: "0x07865c6E87B9F70255377e024ace6630C1Eaa37F", // USDC on Goerli
        initialSigners: [
          "0x1234567890123456789012345678901234567890", // Replace with actual signer addresses
          "0x2345678901234567890123456789012345678901",
          "0x3456789012345678901234567890123456789012",
          "0x4567890123456789012345678901234567890123"
        ],
        requiredSignatures: 3
      };
    
    case "mumbai":
      return {
        daoAddress: "0x1234567890123456789012345678901234567890", // Replace with actual DAO address
        usdcAddress: "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", // USDC on Mumbai
        initialSigners: [
          "0x1234567890123456789012345678901234567890",
          "0x2345678901234567890123456789012345678901",
          "0x3456789012345678901234567890123456789012",
          "0x4567890123456789012345678901234567890123"
        ],
        requiredSignatures: 3
      };
    
    default:
      return null;
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });