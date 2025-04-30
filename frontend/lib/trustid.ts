import { ethers } from 'ethers';
import contracts from '@/config/contracts';

// Contract ABIs (simplified for brevity - replace with actual ABIs)
const TrustIDFactoryABI = [
  "function createIdentity(string username, string metadataURI) external returns (string)",
  "function isUsernameAvailable(string username) external view returns (bool)",
  "function isDIDAvailable(string did) external view returns (bool)",
];

const TrustIDABI = [
  "function getIdentity(string did) external view returns (address owner, string metadataURI, uint256 createdAt, uint256 updatedAt, bool active)",
  "function updateIdentity(string did, string metadataURI) external",
  "function getIdentityCredentials(string did) external view returns (bytes32[])",
  "function getCredential(bytes32 credentialId) external view returns (bytes32 id, address issuer, address subject, string credentialType, string metadataURI, uint256 issuedAt, uint256 expiresAt, bool revoked)",
  "function verifyCredential(bytes32 credentialId) external view returns (bool)",
  "function getReputation(string did) external view returns (uint256 score, uint256 lastUpdated)",
  "function getCategoryReputation(string did, string category) external view returns (uint256)",
];

const AIReputationOracleABI = [
  "function requestReputationUpdate(string did) external",
];

/**
 * Get contract instances based on the current network
 */
export async function getContracts() {
  // Check if window is defined (browser environment)
  if (typeof window === 'undefined') {
    return null;
  }

  // Get the provider
  // @ts-ignore
  const { ethereum } = window;
  if (!ethereum) {
    throw new Error('No Web3 provider detected. Please install MetaMask or a compatible wallet.');
  }

  const provider = new ethers.BrowserProvider(ethereum);
  const network = await provider.getNetwork();
  
  // Determine which network addresses to use
  const networkName = network.chainId === 31n ? 'testnet' :
                      network.chainId === 30n ? 'mainnet' : 
                      'localhost';
  
  const addresses = contracts[networkName];
  
  // Get signer
  const signer = await provider.getSigner();

  // Initialize contracts
  const trustIdFactory = new ethers.Contract(
    addresses.trustIdFactory,
    TrustIDFactoryABI,
    signer
  );

  const trustId = new ethers.Contract(
    addresses.trustId,
    TrustIDABI,
    signer
  );

  const aiReputationOracle = new ethers.Contract(
    addresses.aiReputationOracle,
    AIReputationOracleABI,
    signer
  );

  return {
    trustIdFactory,
    trustId,
    aiReputationOracle,
    provider,
    signer,
    networkName,
  };
}

/**
 * Check if a username is available
 */
export async function isUsernameAvailable(username: string): Promise<boolean> {
  const contracts = await getContracts();
  if (!contracts) return false;
  
  try {
    return await contracts.trustIdFactory.isUsernameAvailable(username);
  } catch (error) {
    console.error('Error checking username availability:', error);
    return false;
  }
}

/**
 * Create a new identity
 */
export async function createIdentity(username: string, metadataURI: string): Promise<string | null> {
  const contracts = await getContracts();
  if (!contracts) return null;
  
  try {
    const tx = await contracts.trustIdFactory.createIdentity(username, metadataURI);
    const receipt = await tx.wait();
    
    // Parse the emitted event to get the created DID
    // This is a simplification - in a real app, you would parse the logs to find the IdentityCreated event
    return `did:rsk:${username}`;
  } catch (error) {
    console.error('Error creating identity:', error);
    return null;
  }
}

/**
 * Get identity details
 */
export async function getIdentity(did: string): Promise<any | null> {
  const contracts = await getContracts();
  if (!contracts) return null;
  
  try {
    const [owner, metadataURI, createdAt, updatedAt, active] = await contracts.trustId.getIdentity(did);
    
    return {
      did,
      owner,
      metadataURI,
      createdAt: Number(createdAt),
      updatedAt: Number(updatedAt),
      active,
    };
  } catch (error) {
    console.error('Error getting identity:', error);
    return null;
  }
}

/**
 * Update identity metadata
 */
export async function updateIdentity(did: string, metadataURI: string): Promise<boolean> {
  const contracts = await getContracts();
  if (!contracts) return false;
  
  try {
    const tx = await contracts.trustId.updateIdentity(did, metadataURI);
    await tx.wait();
    return true;
  } catch (error) {
    console.error('Error updating identity:', error);
    return false;
  }
}

/**
 * Get identity credentials
 */
export async function getIdentityCredentials(did: string): Promise<any[]> {
  const contracts = await getContracts();
  if (!contracts) return [];
  
  try {
    const credentialIds = await contracts.trustId.getIdentityCredentials(did);
    
    // Fetch details for each credential
    const credentials = await Promise.all(
      credentialIds.map(async (id: string) => {
        const [credId, issuer, subject, type, uri, issuedAt, expiresAt, revoked] = 
          await contracts.trustId.getCredential(id);
          
        return {
          id: credId,
          issuer,
          subject,
          type,
          uri,
          issuedAt: Number(issuedAt),
          expiresAt: Number(expiresAt),
          revoked,
          valid: await contracts.trustId.verifyCredential(id),
        };
      })
    );
    
    return credentials;
  } catch (error) {
    console.error('Error getting credentials:', error);
    return [];
  }
}

/**
 * Get reputation score
 */
export async function getReputation(did: string): Promise<any | null> {
  const contracts = await getContracts();
  if (!contracts) return null;
  
  try {
    const [score, lastUpdated] = await contracts.trustId.getReputation(did);
    
    // Get category scores (hardcoded categories for now)
    const categories = ['finance', 'social', 'technical', 'communication'];
    const categoryScores = await Promise.all(
      categories.map(async (category) => {
        const score = await contracts.trustId.getCategoryReputation(did, category);
        return { category, score: Number(score) };
      })
    );
    
    return {
      score: Number(score),
      lastUpdated: Number(lastUpdated),
      categories: categoryScores,
    };
  } catch (error) {
    console.error('Error getting reputation:', error);
    return null;
  }
}

/**
 * Request a reputation update from the AI oracle
 */
export async function requestReputationUpdate(did: string): Promise<boolean> {
  const contracts = await getContracts();
  if (!contracts) return false;
  
  try {
    const tx = await contracts.aiReputationOracle.requestReputationUpdate(did);
    await tx.wait();
    return true;
  } catch (error) {
    console.error('Error requesting reputation update:', error);
    return false;
  }
}

/**
 * Parse a DID to extract the username
 */
export function parseDidToUsername(did: string): string | null {
  if (!did.startsWith('did:rsk:')) {
    return null;
  }
  
  return did.replace('did:rsk:', '');
}

/**
 * Format a username to a DID
 */
export function formatUsernameToDid(username: string): string {
  return `did:rsk:${username}`;
} 