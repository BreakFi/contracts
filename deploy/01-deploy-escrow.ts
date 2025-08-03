import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, network } = hre;
  const { deploy } = deployments;
  const { deployer, dao } = await getNamedAccounts();

  console.log(`Deploying P2P Escrow contract on ${network.name}...`);

  // Deploy the P2P Escrow contract
  const escrowDeployment = await deploy("P2PEscrow", {
    from: deployer,
    args: [dao], // DAO address as constructor parameter
    log: true,
    autoMine: true,
  });

  console.log(`P2P Escrow deployed at: ${escrowDeployment.address}`);

  // Verify contract on block explorer if not local network
  if (network.name !== "hardhat" && network.name !== "localhost") {
    console.log("Waiting for block confirmations...");
    await new Promise(resolve => setTimeout(resolve, 30000)); // Wait 30 seconds
    
    try {
      await hre.run("verify:verify", {
        address: escrowDeployment.address,
        constructorArguments: [dao],
      });
      console.log("P2P Escrow contract verified on block explorer");
    } catch (error) {
      console.log("Verification failed:", error);
    }
  }

  // Save deployment address for other contracts to use
  return true;
};

func.tags = ["P2PEscrow", "core"];
func.id = "deploy_p2p_escrow";

export default func;