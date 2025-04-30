import * as tf from '@tensorflow/tfjs';

// Define the types of activity data we'll analyze
export interface ActivityData {
  transactionCount: number;
  transactionValue: number;
  accountAge: number; // in days
  successfulInteractions: number;
  failedInteractions: number;
  credentialsReceived: number;
  credentialsRevoked: number;
  communityEngagement: number; // 0-100 score
  socialConnections: number;
}

// Categories for reputation scoring
export type ReputationCategory = 'finance' | 'social' | 'technical' | 'communication';

// Initialize TensorFlow models
let financeModel: tf.LayersModel | null = null;
let socialModel: tf.LayersModel | null = null;
let technicalModel: tf.LayersModel | null = null;
let communicationModel: tf.LayersModel | null = null;

// Initialize models when needed
async function initializeModels() {
  try {
    // In a real application, these would be pre-trained models loaded from a server
    // For demo purposes, we'll create simple models that output random scores
    
    // Finance model - evaluates financial reliability
    financeModel = tf.sequential();
    financeModel.add(tf.layers.dense({ units: 10, activation: 'relu', inputShape: [9] }));
    financeModel.add(tf.layers.dense({ units: 5, activation: 'relu' }));
    financeModel.add(tf.layers.dense({ units: 1, activation: 'sigmoid' }));
    
    financeModel.compile({
      optimizer: 'adam',
      loss: 'binaryCrossentropy',
      metrics: ['accuracy'],
    });
    
    // Social model - evaluates social reliability
    socialModel = tf.sequential();
    socialModel.add(tf.layers.dense({ units: 10, activation: 'relu', inputShape: [9] }));
    socialModel.add(tf.layers.dense({ units: 5, activation: 'relu' }));
    socialModel.add(tf.layers.dense({ units: 1, activation: 'sigmoid' }));
    
    socialModel.compile({
      optimizer: 'adam',
      loss: 'binaryCrossentropy',
      metrics: ['accuracy'],
    });
    
    // Technical model - evaluates technical competence
    technicalModel = tf.sequential();
    technicalModel.add(tf.layers.dense({ units: 10, activation: 'relu', inputShape: [9] }));
    technicalModel.add(tf.layers.dense({ units: 5, activation: 'relu' }));
    technicalModel.add(tf.layers.dense({ units: 1, activation: 'sigmoid' }));
    
    technicalModel.compile({
      optimizer: 'adam',
      loss: 'binaryCrossentropy',
      metrics: ['accuracy'],
    });
    
    // Communication model - evaluates communication reliability
    communicationModel = tf.sequential();
    communicationModel.add(tf.layers.dense({ units: 10, activation: 'relu', inputShape: [9] }));
    communicationModel.add(tf.layers.dense({ units: 5, activation: 'relu' }));
    communicationModel.add(tf.layers.dense({ units: 1, activation: 'sigmoid' }));
    
    communicationModel.compile({
      optimizer: 'adam',
      loss: 'binaryCrossentropy',
      metrics: ['accuracy'],
    });
    
    console.log('AI models initialized');
    return true;
  } catch (error) {
    console.error('Error initializing AI models:', error);
    return false;
  }
}

// Normalize the activity data for model input
function normalizeData(data: ActivityData): tf.Tensor {
  // Convert the data to an array and normalize values
  const values = [
    data.transactionCount / 1000, // Normalize to 0-1 range
    data.transactionValue / 1000000, // Normalize large values
    data.accountAge / 365, // Normalize to years
    data.successfulInteractions / 100,
    data.failedInteractions / 100,
    data.credentialsReceived / 20,
    data.credentialsRevoked / 10,
    data.communityEngagement / 100,
    data.socialConnections / 500,
  ];
  
  return tf.tensor2d([values]);
}

// Calculate reputation score for a specific category
async function calculateCategoryScore(
  category: ReputationCategory,
  data: ActivityData
): Promise<number> {
  // Make sure models are initialized
  if (!financeModel || !socialModel || !technicalModel || !communicationModel) {
    await initializeModels();
  }
  
  // Normalize data
  const input = normalizeData(data);
  
  try {
    let prediction: tf.Tensor;
    
    // Use the appropriate model based on the category
    switch (category) {
      case 'finance':
        prediction = financeModel!.predict(input) as tf.Tensor;
        break;
      case 'social':
        prediction = socialModel!.predict(input) as tf.Tensor;
        break;
      case 'technical':
        prediction = technicalModel!.predict(input) as tf.Tensor;
        break;
      case 'communication':
        prediction = communicationModel!.predict(input) as tf.Tensor;
        break;
      default:
        throw new Error(`Unknown category: ${category}`);
    }
    
    // Convert to a 0-1000 score
    const score = await prediction.data();
    return Math.round(score[0] * 1000);
  } catch (error) {
    console.error(`Error calculating ${category} score:`, error);
    return 500; // Default middle score
  }
}

// Calculate overall reputation score based on all categories
export async function calculateReputationScore(data: ActivityData): Promise<{
  overall: number;
  categories: { category: ReputationCategory; score: number }[];
}> {
  // Make sure models are initialized
  if (!financeModel || !socialModel || !technicalModel || !communicationModel) {
    await initializeModels();
  }
  
  const categories: ReputationCategory[] = ['finance', 'social', 'technical', 'communication'];
  
  // Calculate scores for each category
  const categoryScores = await Promise.all(
    categories.map(async (category) => ({
      category,
      score: await calculateCategoryScore(category, data),
    }))
  );
  
  // Calculate overall score (weighted average)
  const weights = {
    finance: 0.3,
    social: 0.25,
    technical: 0.25,
    communication: 0.2,
  };
  
  const overall = categoryScores.reduce(
    (sum, { category, score }) => sum + score * weights[category],
    0
  );
  
  return {
    overall: Math.round(overall),
    categories: categoryScores,
  };
}

// Fetch on-chain activity data for a DID
export async function fetchActivityData(did: string): Promise<ActivityData> {
  // This would typically involve querying blockchain data, credential issuers, etc.
  // For demo purposes, we'll return mock data
  
  // In a real application, you would:
  // 1. Fetch transaction history from blockchain
  // 2. Analyze credential issuance and verification
  // 3. Check social connections and interactions
  // 4. Gather community participation metrics
  
  // Mock data generation (randomized)
  const mockData: ActivityData = {
    transactionCount: Math.floor(Math.random() * 500),
    transactionValue: Math.floor(Math.random() * 1000000),
    accountAge: Math.floor(Math.random() * 365 * 3), // Up to 3 years
    successfulInteractions: Math.floor(Math.random() * 100),
    failedInteractions: Math.floor(Math.random() * 20),
    credentialsReceived: Math.floor(Math.random() * 15),
    credentialsRevoked: Math.floor(Math.random() * 3),
    communityEngagement: Math.floor(Math.random() * 100),
    socialConnections: Math.floor(Math.random() * 200),
  };
  
  return mockData;
}

// Generate a full reputation report
export async function generateReputationReport(did: string): Promise<{
  did: string;
  overall: number;
  categories: { category: ReputationCategory; score: number }[];
  activityData: ActivityData;
  timestamp: number;
}> {
  // Fetch activity data
  const activityData = await fetchActivityData(did);
  
  // Calculate reputation score
  const { overall, categories } = await calculateReputationScore(activityData);
  
  return {
    did,
    overall,
    categories,
    activityData,
    timestamp: Date.now(),
  };
}

// Initialize models when module is imported
initializeModels(); 