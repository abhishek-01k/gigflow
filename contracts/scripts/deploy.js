// Script to deploy all GigFlow smart contracts

const { ethers, network } = require("hardhat");
const { verify } = require("../utils/verify");

async function main() {
  console.log("Starting GigFlow contracts deployment...");
  
  // Get deployer account
  const [deployer] = await ethers.getSigners();
  const deployerAddress = await deployer.getAddress();
  console.log(`Deploying contracts with account: ${deployerAddress}`);
  
  // Check account balance
  const balance = await deployer.getBalance();
  console.log(`Account balance: ${ethers.utils.formatEther(balance)} ETH`);
  
  // Define constants
  const PLATFORM_FEE_PERCENT = 5; // 5% platform fee
  const BLOCK_CONFIRMATIONS = 6; 
  
  // Deploy GigFlowToken
  console.log("Deploying GigFlowToken...");
  const TokenFactory = await ethers.getContractFactory("GigFlowToken");
  const token = await TokenFactory.deploy();
  await token.deployed();
  console.log(`GigFlowToken deployed to: ${token.address}`);
  
  // Deploy GigFlowMarketplace
  console.log("Deploying GigFlowMarketplace...");
  const MarketplaceFactory = await ethers.getContractFactory("GigFlowMarketplace");
  const marketplace = await MarketplaceFactory.deploy(
    PLATFORM_FEE_PERCENT,
    deployerAddress, // Set deployer as fee collector initially
    token.address
  );
  await marketplace.deployed();
  console.log(`GigFlowMarketplace deployed to: ${marketplace.address}`);
  
  // Deploy AIMatchingOracle
  console.log("Deploying AIMatchingOracle...");
  const MatchingOracleFactory = await ethers.getContractFactory("AIMatchingOracle");
  const matchingOracle = await MatchingOracleFactory.deploy();
  await matchingOracle.deployed();
  console.log(`AIMatchingOracle deployed to: ${matchingOracle.address}`);
  
  // Deploy AISkillVerifier
  console.log("Deploying AISkillVerifier...");
  const SkillVerifierFactory = await ethers.getContractFactory("AISkillVerifier");
  const skillVerifier = await SkillVerifierFactory.deploy();
  await skillVerifier.deployed();
  console.log(`AISkillVerifier deployed to: ${skillVerifier.address}`);
  
  // Deploy GigFlowDisputeResolver
  console.log("Deploying GigFlowDisputeResolver...");
  const DisputeResolverFactory = await ethers.getContractFactory("GigFlowDisputeResolver");
  const disputeResolver = await DisputeResolverFactory.deploy();
  await disputeResolver.deployed();
  console.log(`GigFlowDisputeResolver deployed to: ${disputeResolver.address}`);
  
  // Link contracts together
  console.log("Linking contracts together...");
  
  // Set marketplace address in oracles
  let tx = await matchingOracle.setMarketplaceAddress(marketplace.address);
  await tx.wait();
  console.log("Set marketplace address in AIMatchingOracle");
  
  tx = await skillVerifier.setMarketplaceAddress(marketplace.address);
  await tx.wait();
  console.log("Set marketplace address in AISkillVerifier");
  
  // Set oracle addresses in marketplace
  tx = await marketplace.setMatchingOracle(matchingOracle.address);
  await tx.wait();
  console.log("Set matching oracle in marketplace");
  
  tx = await marketplace.setSkillVerifier(skillVerifier.address);
  await tx.wait();
  console.log("Set skill verifier in marketplace");
  
  // Link dispute resolver to marketplace
  tx = await marketplace.setDisputeResolver(disputeResolver.address);
  await tx.wait();
  console.log("Set dispute resolver in marketplace");
  
  tx = await disputeResolver.setMarketplaceAddress(marketplace.address);
  await tx.wait();
  console.log("Set marketplace address in dispute resolver");
  
  // Add some test AI service providers to the oracles (in a production environment, these would be added through governance)
  const testProviders = [
    "0x70997970C51812dc3A010C7d01b50e0d17dc79C8", // Test address
    "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"  // Test address
  ];
  
  console.log("Adding test AI service providers to oracles...");
  for (const provider of testProviders) {
    tx = await matchingOracle.addAIServiceProvider(provider);
    await tx.wait();
    console.log(`Added ${provider} as matching service provider`);
    
    tx = await skillVerifier.addAIServiceProvider(provider);
    await tx.wait();
    console.log(`Added ${provider} as skill verification provider`);
  }
  
  console.log("Deployment and configuration complete!");
  
  // Wait for block confirmations before verification
  if (network.name !== "localhost" && network.name !== "hardhat") {
    console.log(`Waiting for ${BLOCK_CONFIRMATIONS} confirmations before verification...`);
    await token.deployTransaction.wait(BLOCK_CONFIRMATIONS);
    await marketplace.deployTransaction.wait(BLOCK_CONFIRMATIONS);
    await matchingOracle.deployTransaction.wait(BLOCK_CONFIRMATIONS);
    await skillVerifier.deployTransaction.wait(BLOCK_CONFIRMATIONS);
    await disputeResolver.deployTransaction.wait(BLOCK_CONFIRMATIONS);
    
    // Verify contracts on block explorer
    console.log("Verifying contracts on block explorer...");
    
    await verify(token.address, []);
    await verify(marketplace.address, [
      PLATFORM_FEE_PERCENT,
      deployerAddress,
      token.address
    ]);
    await verify(matchingOracle.address, []);
    await verify(skillVerifier.address, []);
    await verify(disputeResolver.address, []);
  }
  
  // Print summary of deployed contracts
  console.log("DEPLOYMENT SUMMARY");
  console.log("===================");
  console.log(`GigFlowToken: ${token.address}`);
  console.log(`GigFlowMarketplace: ${marketplace.address}`);
  console.log(`AIMatchingOracle: ${matchingOracle.address}`);
  console.log(`AISkillVerifier: ${skillVerifier.address}`);
  console.log(`GigFlowDisputeResolver: ${disputeResolver.address}`);
  console.log("===================");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 