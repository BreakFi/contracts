import { ethers } from "hardhat";
import hre from "hardhat";

/**
 * Script to deploy the full system on local network for development
 */
async function main() {
  console.log("🚀 Deploying complete system on local network...\n");

  const [deployer, dao, arbitrator, signer1, signer2] = await ethers.getSigners();
  
  console.log("📋 Account Setup:");
  console.log(`Deployer: ${deployer.address}`);
  console.log(`DAO: ${dao.address}`);
  console.log(`Arbitrator: ${arbitrator.address}`);
  console.log(`Signer 1: ${signer1.address}`);
  console.log(`Signer 2: ${signer2.address}\n`);

  // Deploy mock USDC for testing
  console.log("💰 Deploying Mock USDC...");
  const MockERC20 = await ethers.getContractFactory("MockERC20");
  const usdc = await MockERC20.deploy("USD Coin", "USDC", 6);
  await usdc.waitForDeployment();
  const usdcAddress = await usdc.getAddress();
  console.log(`Mock USDC deployed at: ${usdcAddress}\n`);

  // Deploy P2P Escrow
  console.log("🔒 Deploying P2P Escrow...");
  const P2PEscrow = await ethers.getContractFactory("P2PEscrow");
  const escrow = await P2PEscrow.deploy(dao.address);
  await escrow.waitForDeployment();
  const escrowAddress = await escrow.getAddress();
  console.log(`P2P Escrow deployed at: ${escrowAddress}\n`);

  // Deploy Reputation Registry
  console.log("⭐ Deploying Reputation Registry...");
  const ReputationRegistry = await ethers.getContractFactory("ReputationRegistry");
  const reputation = await ReputationRegistry.deploy(dao.address, usdcAddress);
  await reputation.waitForDeployment();
  const reputationAddress = await reputation.getAddress();
  console.log(`Reputation Registry deployed at: ${reputationAddress}\n`);

  // Deploy Platform DAO
  console.log("🏛️  Deploying Platform DAO...");
  const PlatformDAO = await ethers.getContractFactory("PlatformDAO");
  const initialSigners = [dao.address, arbitrator.address, signer1.address, signer2.address];
  const requiredSignatures = 3; // 3 of 4 multi-sig
  
  const platformDAO = await PlatformDAO.deploy(
    initialSigners,
    requiredSignatures,
    escrowAddress,
    reputationAddress
  );
  await platformDAO.waitForDeployment();
  const platformDAOAddress = await platformDAO.getAddress();
  console.log(`Platform DAO deployed at: ${platformDAOAddress}\n`);

  // Configure the system
  console.log("⚙️  Configuring system...");
  
  // Add USDC as supported token
  await escrow.connect(dao).addSupportedToken(usdcAddress, "USDC", 6);
  console.log("✅ Added USDC as supported token");

  // Set up some initial parameters
  const baseFeeKey = ethers.keccak256(ethers.toUtf8Bytes("BASE_FEE_PERCENTAGE"));
  await escrow.connect(dao).updateParameter(baseFeeKey, 150); // 1.5%
  console.log("✅ Set base fee to 1.5%");

  // Grant DAO role to Platform DAO contract
  const DAO_ROLE = await escrow.DAO_ROLE();
  await escrow.connect(dao).grantRole(DAO_ROLE, platformDAOAddress);
  await reputation.connect(dao).grantRole(DAO_ROLE, platformDAOAddress);
  console.log("✅ Granted DAO roles to Platform DAO contract");

  // Add arbitrator
  await escrow.connect(dao).addAuthorizedArbitrator(arbitrator.address, 0);
  console.log("✅ Added authorized arbitrator");

  // Mint some USDC for testing
  const testAmount = ethers.parseUnits("10000", 6); // 10,000 USDC
  await usdc.mint(deployer.address, testAmount);
  await usdc.mint(dao.address, testAmount);
  await usdc.mint(arbitrator.address, testAmount);
  await usdc.mint(signer1.address, testAmount);
  await usdc.mint(signer2.address, testAmount);
  console.log("✅ Minted test USDC for all accounts");

  console.log("\n🎉 Local deployment completed!");
  console.log("\n📋 CONTRACT ADDRESSES:");
  console.log("=====================");
  console.log(`Mock USDC:           ${usdcAddress}`);
  console.log(`P2P Escrow:          ${escrowAddress}`);
  console.log(`Reputation Registry: ${reputationAddress}`);
  console.log(`Platform DAO:        ${platformDAOAddress}`);
  
  console.log("\n🔧 CONFIGURATION:");
  console.log("=================");
  console.log(`Multi-sig signers: ${initialSigners.length}`);
  console.log(`Required signatures: ${requiredSignatures}`);
  console.log(`Base fee: 1.5%`);
  console.log(`Supported tokens: USDC`);

  console.log("\n💡 NEXT STEPS:");
  console.log("==============");
  console.log("1. Run integration tests: npx hardhat test");
  console.log("2. Start local node: npx hardhat node");
  console.log("3. Deploy to testnet when ready");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });