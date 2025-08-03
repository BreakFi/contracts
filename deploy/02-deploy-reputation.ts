import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, network } = hre;
  const { deploy, get } = deployments;
  const { deployer, dao } = await getNamedAccounts();

  console.log(`Deploying Reputation Registry contract on ${network.name}...`);

  // Get USDC address based on network
  let usdcAddress: string;
  switch (network.name) {
    case "mainnet":
      usdcAddress = "0xA0b86a33E6441C8BB6f7d0E9c07fcb5b22E5EbD7"; // USDC on Ethereum mainnet
      break;
    case "polygon":
      usdcAddress = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174"; // USDC on Polygon
      break;
    case "arbitrum":
      usdcAddress = "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8"; // USDC on Arbitrum
      break;
    case "goerli":
      usdcAddress = "0x07865c6E87B9F70255377e024ace6630C1Eaa37F"; // USDC on Goerli testnet
      break;
    default:
      // For local/test networks, deploy a mock USDC
      const mockUSDC = await deploy("MockERC20", {
        from: deployer,
        args: ["USD Coin", "USDC", 6],
        log: true,
      });
      usdcAddress = mockUSDC.address;
      console.log(`Mock USDC deployed at: ${usdcAddress}`);
  }

  // Deploy the Reputation Registry contract
  const reputationDeployment = await deploy("ReputationRegistry", {
    from: deployer,
    args: [dao, usdcAddress], // DAO address and USDC address as constructor parameters
    log: true,
    autoMine: true,
  });

  console.log(`Reputation Registry deployed at: ${reputationDeployment.address}`);

  // Verify contract on block explorer if not local network
  if (network.name !== "hardhat" && network.name !== "localhost") {
    console.log("Waiting for block confirmations...");
    await new Promise(resolve => setTimeout(resolve, 30000)); // Wait 30 seconds
    
    try {
      await hre.run("verify:verify", {
        address: reputationDeployment.address,
        constructorArguments: [dao, usdcAddress],
      });
      console.log("Reputation Registry contract verified on block explorer");
    } catch (error) {
      console.log("Verification failed:", error);
    }
  }

  return true;
};

func.tags = ["ReputationRegistry", "core"];
func.id = "deploy_reputation_registry";
func.dependencies = ["P2PEscrow"];

export default func;