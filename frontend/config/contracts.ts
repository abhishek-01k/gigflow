export type ContractAddresses = {
  trustId: string;
  trustIdFactory: string;
  aiReputationOracle: string;
};

// Contract addresses for different networks
const contracts: Record<string, ContractAddresses> = {
  // RSK Testnet addresses
  testnet: {
    trustId: "0x0000000000000000000000000000000000000000", // Replace with actual deployed address
    trustIdFactory: "0x0000000000000000000000000000000000000000", // Replace with actual deployed address
    aiReputationOracle: "0x0000000000000000000000000000000000000000", // Replace with actual deployed address
  },
  // RSK Mainnet addresses
  mainnet: {
    trustId: "0x0000000000000000000000000000000000000000", // Replace with actual deployed address
    trustIdFactory: "0x0000000000000000000000000000000000000000", // Replace with actual deployed address
    aiReputationOracle: "0x0000000000000000000000000000000000000000", // Replace with actual deployed address
  },
  // Local development
  localhost: {
    trustId: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
    trustIdFactory: "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512",
    aiReputationOracle: "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0",
  },
};

export default contracts; 