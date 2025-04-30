"use client";

import { useState } from "react";
import { createIdentity, isUsernameAvailable } from "@/lib/trustid";

export default function CreateIdentity() {
  const [username, setUsername] = useState("");
  const [fullName, setFullName] = useState("");
  const [bio, setBio] = useState("");
  const [usernameAvailable, setUsernameAvailable] = useState<boolean | null>(null);
  const [isCreating, setIsCreating] = useState(false);
  const [errorMessage, setErrorMessage] = useState("");
  const [successMessage, setSuccessMessage] = useState("");

  const checkUsername = async () => {
    if (!username) return;
    
    try {
      const available = await isUsernameAvailable(username);
      setUsernameAvailable(available);
      if (!available) {
        setErrorMessage("This username is already taken. Please choose another one.");
      } else {
        setErrorMessage("");
      }
    } catch (error) {
      console.error("Error checking username:", error);
      setErrorMessage("Error checking username availability. Please try again.");
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!username || !fullName) {
      setErrorMessage("Username and full name are required.");
      return;
    }
    
    if (usernameAvailable !== true) {
      await checkUsername();
      if (usernameAvailable !== true) {
        return;
      }
    }
    
    setIsCreating(true);
    setErrorMessage("");
    
    try {
      // Create metadata object to store on IPFS or similar
      const metadata = {
        fullName,
        bio,
        avatar: "", // Could add avatar upload feature
        createdAt: new Date().toISOString(),
      };
      
      // In a real app, we would upload this to IPFS
      // For demo, we'll stringify and use as-is
      const metadataURI = `data:application/json,${encodeURIComponent(JSON.stringify(metadata))}`;
      
      // Create identity on blockchain
      const did = await createIdentity(username, metadataURI);
      
      if (did) {
        setSuccessMessage(`Identity created successfully! Your DID is: ${did}`);
        // In a real app, you would redirect to the identity page
        // router.push(`/identity/${did}`);
      } else {
        setErrorMessage("Failed to create identity. Please try again.");
      }
    } catch (error) {
      console.error("Error creating identity:", error);
      setErrorMessage("Error creating identity. Please make sure your wallet is connected and try again.");
    } finally {
      setIsCreating(false);
    }
  };

  return (
    <div className="max-w-md mx-auto p-6 bg-white rounded-lg shadow-md">
      <h1 className="text-2xl font-bold mb-6">Create Your Digital Identity</h1>
      
      {successMessage ? (
        <div className="bg-green-100 border border-green-400 text-green-700 px-4 py-3 rounded mb-4">
          <p>{successMessage}</p>
          <div className="mt-4">
            <a 
              href="/" 
              className="inline-flex h-10 items-center justify-center rounded-md bg-blue-600 px-8 text-sm font-medium text-white shadow transition-colors hover:bg-blue-700 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-700"
            >
              Return Home
            </a>
          </div>
        </div>
      ) : (
        <form onSubmit={handleSubmit}>
          {errorMessage && (
            <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
              <p>{errorMessage}</p>
            </div>
          )}
          
          <div className="mb-4">
            <label className="block text-gray-700 font-bold mb-2" htmlFor="username">
              Username (Required)
            </label>
            <div className="flex">
              <input
                type="text"
                id="username"
                value={username}
                onChange={(e) => {
                  setUsername(e.target.value);
                  setUsernameAvailable(null);
                }}
                className="shadow appearance-none border rounded-l w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline"
                placeholder="Enter a unique username"
              />
              <button
                type="button"
                onClick={checkUsername}
                className="bg-gray-200 hover:bg-gray-300 text-gray-800 font-bold py-2 px-4 rounded-r"
              >
                Check
              </button>
            </div>
            {usernameAvailable === true && (
              <p className="text-green-500 text-sm mt-1">Username is available!</p>
            )}
            <p className="text-gray-500 text-xs mt-1">This will be used in your DID: did:rsk:username</p>
          </div>
          
          <div className="mb-4">
            <label className="block text-gray-700 font-bold mb-2" htmlFor="fullName">
              Full Name (Required)
            </label>
            <input
              type="text"
              id="fullName"
              value={fullName}
              onChange={(e) => setFullName(e.target.value)}
              className="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline"
              placeholder="Enter your full name"
            />
          </div>
          
          <div className="mb-6">
            <label className="block text-gray-700 font-bold mb-2" htmlFor="bio">
              Bio (Optional)
            </label>
            <textarea
              id="bio"
              value={bio}
              onChange={(e) => setBio(e.target.value)}
              className="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline"
              placeholder="Tell us about yourself"
              rows={4}
            />
          </div>
          
          <div className="flex items-center justify-between">
            <button
              type="submit"
              disabled={isCreating}
              className={`bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded focus:outline-none focus:shadow-outline ${
                isCreating ? "opacity-50 cursor-not-allowed" : ""
              }`}
            >
              {isCreating ? "Creating..." : "Create Identity"}
            </button>
            <a
              href="/"
              className="inline-block align-baseline font-bold text-sm text-blue-500 hover:text-blue-800"
            >
              Cancel
            </a>
          </div>
        </form>
      )}
    </div>
  );
} 