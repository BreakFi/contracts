import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, network } = hre;
  const { deploy, get } = deployments;
  const { deployer, dao, signer1, signer2, signer3 } = await getNamedAccounts();

  console.log(`Deploying Platform DAO contract on ${network.name}...`);

  // Get previously deployed contract addresses
  const escrowDeployment = await get("P2PEscrow");
  const reputationDeployment = await get("ReputationRegistry");

  // Set up initial signers (adjust based on your needs)
  const initialSigners = [dao, signer1, signer2, signer3].filter(addr => addr && addr !== "");
  const requiredSignatures = Math.max(2, Math.floor(initialSigners.length * 0.6)); // 60% threshold

  console.log(`Initial signers: ${initialSigners}`);
  console.log(`Required signatures: ${requiredSignatures}`);

  // Deploy the Platform DAO contract
  const daoDeployment = await deploy("PlatformDAO", {
    from: deployer,
    args: [
      initialSigners,
      requiredSignatures,
      escrowDeployment.address,
      reputationDeployment.address
    ],
    log: true,
    autoMine: true,
  });

  console.log(`Platform DAO deployed at: ${daoDeployment.address}`);

  // Verify contract on block explorer if not local network
  if (network.name !== "hardhat" && network.name !== "localhost") {
    console.log("Waiting for block confirmations...");
    await new Promise(resolve => setTimeout(resolve, 30000)); // Wait 30 seconds
    
    try {
      await hre.run("verify:verify", {
        address: daoDeployment.address,
        constructorArguments: [
          initialSigners,
          requiredSignatures,
          escrowDeployment.address,
          reputationDeployment.address
        ],
      });
      console.log("Platform DAO contract verified on block explorer");
    } catch (error) {
      console.log("Verification failed:", error);
    }
  }

  return true;
};

func.tags = ["PlatformDAO", "core"];
func.id = "deploy_platform_dao";
func.dependencies = ["P2PEscrow", "ReputationRegistry"];

export default func;