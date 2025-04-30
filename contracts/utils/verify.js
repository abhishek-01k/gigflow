const { run } = require("hardhat");

/**
 * Verify a contract on Etherscan or other block explorers
 * @param {string} contractAddress - The address of the deployed contract
 * @param {Array} constructorArguments - The arguments passed to the contract constructor
 */
async function verify(contractAddress, constructorArguments) {
  console.log(`Verifying contract at ${contractAddress}`);
  
  try {
    await run("verify:verify", {
      address: contractAddress,
      constructorArguments: constructorArguments,
    });
    console.log(`Contract verified successfully: ${contractAddress}`);
  } catch (error) {
    if (error.message.includes("already verified")) {
      console.log("Contract is already verified!");
    } else {
      console.error(`Error verifying contract: ${error.message}`);
    }
  }
}

module.exports = { verify }; 