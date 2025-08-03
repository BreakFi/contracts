import hre from "hardhat";

/**
 * Script to verify deployed contracts on block explorers
 * Usage: npx hardhat run scripts/verify-contracts.ts --network <network>
 */
async function main() {
  const networkName = hre.network.name;
  console.log(`🔍 Verifying contracts on ${networkName}...\n`);

  // Contract addresses - replace with actual deployed addresses
  const contracts = {
    escrow: "0x...", // Replace with actual P2P Escrow address
    reputation: "0x...", // Replace with actual Reputation Registry address
    dao: "0x...", // Replace with actual Platform DAO address
  };

  // Constructor arguments - replace with actual values used during deployment
  const constructorArgs = {
    escrow: ["0x..."], // DAO address
    reputation: ["0x...", "0x..."], // DAO address, USDC address
    dao: [
      ["0x...", "0x...", "0x...", "0x..."], // initial signers array
      3, // required signatures
      "0x...", // escrow address
      "0x..." // reputation address
    ]
  };

  // Verify P2P Escrow
  if (contracts.escrow !== "0x...") {
    console.log("🔒 Verifying P2P Escrow...");
    try {
      await hre.run("verify:verify", {
        address: contracts.escrow,
        constructorArguments: constructorArgs.escrow,
      });
      console.log("✅ P2P Escrow verified successfully");
    } catch (error) {
      console.log("❌ P2P Escrow verification failed:", error.message);
    }
  }

  // Verify Reputation Registry
  if (contracts.reputation !== "0x...") {
    console.log("\n⭐ Verifying Reputation Registry...");
    try {
      await hre.run("verify:verify", {
        address: contracts.reputation,
        constructorArguments: constructorArgs.reputation,
      });
      console.log("✅ Reputation Registry verified successfully");
    } catch (error) {
      console.log("❌ Reputation Registry verification failed:", error.message);
    }
  }

  // Verify Platform DAO
  if (contracts.dao !== "0x...") {
    console.log("\n🏛️  Verifying Platform DAO...");
    try {
      await hre.run("verify:verify", {
        address: contracts.dao,
        constructorArguments: constructorArgs.dao,
      });
      console.log("✅ Platform DAO verified successfully");
    } catch (error) {
      console.log("❌ Platform DAO verification failed:", error.message);
    }
  }

  console.log("\n🎉 Contract verification completed!");
  
  console.log("\n📋 VERIFIED CONTRACTS:");
  console.log("=====================");
  console.log(`Network: ${networkName}`);
  console.log(`P2P Escrow: ${contracts.escrow}`);
  console.log(`Reputation Registry: ${contracts.reputation}`);
  console.log(`Platform DAO: ${contracts.dao}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });