"use client";

import { useState } from "react";
import { getReputation, formatUsernameToDid } from "@/lib/trustid";
import { generateReputationReport } from "@/lib/aiScoring";

export default function ReputationPage() {
  const [username, setUsername] = useState("");
  const [did, setDid] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [reputation, setReputation] = useState<any>(null);

  const handleSearch = async () => {
    if (!username && !did) {
      setError("Please enter a username or DID");
      return;
    }

    setLoading(true);
    setError("");
    setReputation(null);

    try {
      // Determine the DID from input
      const identityDid = did ? did : formatUsernameToDid(username);
      
      // First try to get on-chain reputation
      try {
        const onChainRep = await getReputation(identityDid);
        if (onChainRep) {
          setReputation(onChainRep);
          setLoading(false);
          return;
        }
      } catch (error) {
        console.log("On-chain reputation not found, generating AI report");
      }
      
      // If no on-chain reputation, generate an AI-based one
      const aiReport = await generateReputationReport(identityDid);
      setReputation(aiReport);
    } catch (error) {
      console.error("Error fetching reputation:", error);
      setError("Failed to fetch reputation. Please ensure the DID exists and try again.");
    } finally {
      setLoading(false);
    }
  };

  const getScoreColor = (score: number) => {
    if (score >= 800) return "text-green-600";
    if (score >= 600) return "text-blue-600";
    if (score >= 400) return "text-yellow-600";
    return "text-red-600";
  };

  const getScoreLabel = (score: number) => {
    if (score >= 800) return "Excellent";
    if (score >= 600) return "Good";
    if (score >= 400) return "Average";
    if (score >= 200) return "Poor";
    return "Very Poor";
  };

  return (
    <div className="max-w-2xl mx-auto p-6">
      <h1 className="text-3xl font-bold mb-6">Reputation Score</h1>
      
      <div className="bg-white rounded-lg shadow-md p-6 mb-8">
        <h2 className="text-xl font-bold mb-4">Search Identity</h2>
        
        <div className="mb-4">
          <label className="block text-gray-700 font-bold mb-2" htmlFor="username">
            Username
          </label>
          <input
            type="text"
            id="username"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            className="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline"
            placeholder="Enter username"
            disabled={!!did}
          />
        </div>
        
        <div className="mb-4">
          <label className="block text-gray-700 font-bold mb-2" htmlFor="did">
            DID
          </label>
          <input
            type="text"
            id="did"
            value={did}
            onChange={(e) => setDid(e.target.value)}
            className="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline"
            placeholder="Enter DID (did:rsk:username)"
            disabled={!!username}
          />
        </div>
        
        <div className="flex items-center justify-between">
          <button
            onClick={handleSearch}
            disabled={loading}
            className={`bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded focus:outline-none focus:shadow-outline ${
              loading ? "opacity-50 cursor-not-allowed" : ""
            }`}
          >
            {loading ? "Searching..." : "Search"}
          </button>
          <button
            onClick={() => {
              setUsername("");
              setDid("");
              setError("");
              setReputation(null);
            }}
            className="inline-block align-baseline font-bold text-sm text-blue-500 hover:text-blue-800"
          >
            Clear
          </button>
        </div>
        
        {error && (
          <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mt-4">
            <p>{error}</p>
          </div>
        )}
      </div>
      
      {reputation && (
        <div className="bg-white rounded-lg shadow-md p-6">
          <h2 className="text-xl font-bold mb-4">Reputation Report</h2>
          
          <div className="mb-6 text-center">
            <div className="text-5xl font-bold mb-2 inline-block">
              <span className={getScoreColor(reputation.overall)}>
                {reputation.overall}
              </span>
              <span className="text-gray-500 text-base ml-2">/ 1000</span>
            </div>
            <div className={`text-xl font-semibold ${getScoreColor(reputation.overall)}`}>
              {getScoreLabel(reputation.overall)}
            </div>
            <div className="text-sm text-gray-500 mt-1">
              Last updated: {new Date(reputation.timestamp || reputation.lastUpdated * 1000).toLocaleString()}
            </div>
          </div>
          
          <div className="mb-6">
            <h3 className="text-lg font-semibold mb-2">Category Scores</h3>
            <div className="space-y-4">
              {reputation.categories && reputation.categories.map((category: any) => (
                <div key={category.category}>
                  <div className="flex justify-between mb-1">
                    <span className="text-gray-700 font-medium capitalize">
                      {category.category}
                    </span>
                    <span className={`font-medium ${getScoreColor(category.score)}`}>
                      {category.score}
                    </span>
                  </div>
                  <div className="w-full bg-gray-200 rounded-full h-2.5">
                    <div
                      className={`h-2.5 rounded-full ${
                        category.score >= 800 ? "bg-green-600" :
                        category.score >= 600 ? "bg-blue-600" :
                        category.score >= 400 ? "bg-yellow-600" :
                        "bg-red-600"
                      }`}
                      style={{ width: `${(category.score / 1000) * 100}%` }}
                    ></div>
                  </div>
                </div>
              ))}
            </div>
          </div>
          
          {reputation.activityData && (
            <div>
              <h3 className="text-lg font-semibold mb-2">Activity Data</h3>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <div className="text-sm text-gray-500">Transaction Count</div>
                  <div className="font-medium">{reputation.activityData.transactionCount}</div>
                </div>
                <div>
                  <div className="text-sm text-gray-500">Transaction Value</div>
                  <div className="font-medium">{reputation.activityData.transactionValue} RBTC</div>
                </div>
                <div>
                  <div className="text-sm text-gray-500">Account Age</div>
                  <div className="font-medium">{Math.round(reputation.activityData.accountAge / 30)} months</div>
                </div>
                <div>
                  <div className="text-sm text-gray-500">Successful Interactions</div>
                  <div className="font-medium">{reputation.activityData.successfulInteractions}</div>
                </div>
                <div>
                  <div className="text-sm text-gray-500">Failed Interactions</div>
                  <div className="font-medium">{reputation.activityData.failedInteractions}</div>
                </div>
                <div>
                  <div className="text-sm text-gray-500">Credentials Received</div>
                  <div className="font-medium">{reputation.activityData.credentialsReceived}</div>
                </div>
              </div>
            </div>
          )}
          
          <div className="mt-6 text-center">
            <button
              onClick={() => window.print()}
              className="bg-gray-200 hover:bg-gray-300 text-gray-800 font-bold py-2 px-4 rounded focus:outline-none focus:shadow-outline"
            >
              Print Report
            </button>
          </div>
        </div>
      )}
    </div>
  );
} 