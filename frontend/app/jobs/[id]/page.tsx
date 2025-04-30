"use client";

import { useState } from "react";
import Link from "next/link";
import { useParams } from "next/navigation";

// Mock job data - in a real app, this would be fetched from an API based on the ID
const jobsData = [
  {
    id: "1",
    title: "Develop Smart Contract for NFT Marketplace",
    description: `We're looking for an experienced Solidity developer to create a comprehensive suite of smart contracts for our NFT marketplace on Rootstock.

The contracts should include:
- NFT minting functionality
- Marketplace for buying and selling
- Auction mechanism
- Royalty distribution
- Admin controls

You should have strong experience with ERC-721 and ERC-1155 standards, and be familiar with Rootstock's specificities.`,
    budget: "2000 RBTC",
    deadline: "August 15, 2023",
    skills: ["Solidity", "Smart Contracts", "NFT", "Rootstock", "ERC-721", "ERC-1155"],
    category: "Smart Contracts",
    client: {
      name: "CryptoInnovations",
      rating: 4.9,
      jobsPosted: 12,
      memberSince: "January 2022",
      location: "Remote"
    },
    proposals: 4,
    status: "Open"
  },
  {
    id: "2",
    title: "Frontend Developer for DeFi Dashboard",
    description: `We need a skilled React developer to build a user-friendly dashboard for our DeFi application with Web3 integration.

Key requirements:
- Clean, responsive UI using React, TypeScript and Tailwind CSS
- Web3 wallet integration (Metamask, WalletConnect)
- Real-time data visualization with charts
- Transaction history and monitoring
- Optimized performance for various devices

Candidates should be familiar with connecting to blockchain RPC endpoints and handling blockchain data.`,
    budget: "3500 RBTC",
    deadline: "September 5, 2023",
    skills: ["React", "TypeScript", "Web3.js", "UI/UX", "Tailwind CSS", "DeFi"],
    category: "Frontend Development",
    client: {
      name: "DeFiSolutions",
      rating: 4.7,
      jobsPosted: 8,
      memberSince: "March 2022",
      location: "Remote"
    },
    proposals: 7,
    status: "Open"
  }
];

export default function JobDetailsPage() {
  const params = useParams();
  const jobId = params.id as string;
  
  // Find the job by ID from our mock data
  const job = jobsData.find(j => j.id === jobId);
  
  const [showProposalForm, setShowProposalForm] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [submitSuccess, setSubmitSuccess] = useState(false);
  const [proposalData, setProposalData] = useState({
    coverLetter: "",
    price: "",
    estimatedTime: "",
    attachments: null as FileList | null
  });
  
  const handleProposalChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target;
    setProposalData(prev => ({ ...prev, [name]: value }));
  };
  
  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files) {
      setProposalData(prev => ({ ...prev, attachments: e.target.files }));
    }
  };
  
  const handleSubmitProposal = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    
    // Simulate API call
    await new Promise(resolve => setTimeout(resolve, 1500));
    
    setIsSubmitting(false);
    setSubmitSuccess(true);
    setShowProposalForm(false);
  };
  
  if (!job) {
    return (
      <div className="container mx-auto px-4 py-16 text-center">
        <h1 className="text-3xl font-bold mb-4">Job Not Found</h1>
        <p className="text-gray-600 mb-8">The job you're looking for doesn't exist or has been removed.</p>
        <Link
          href="/jobs"
          className="inline-flex items-center justify-center px-5 py-3 border border-transparent rounded-md shadow-sm text-base font-medium text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
        >
          Browse Available Jobs
        </Link>
      </div>
    );
  }
  
  return (
    <div className="container mx-auto px-4 py-8">
      {submitSuccess && (
        <div className="mb-8 bg-green-50 border-l-4 border-green-500 p-4">
          <div className="flex">
            <div className="flex-shrink-0">
              <svg className="h-5 w-5 text-green-400" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
              </svg>
            </div>
            <div className="ml-3">
              <p className="text-sm text-green-800">
                Your proposal has been submitted successfully! The client will review it and contact you if interested.
              </p>
            </div>
          </div>
        </div>
      )}
      
      <div className="flex flex-col lg:flex-row gap-8">
        {/* Main content */}
        <div className="lg:w-2/3">
          <div className="bg-white rounded-lg shadow overflow-hidden mb-8">
            <div className="p-6">
              <h1 className="text-2xl font-bold text-gray-900 mb-4">{job.title}</h1>
              <div className="flex flex-wrap gap-2 mb-6">
                <span className="px-3 py-1 bg-blue-100 text-blue-800 text-sm font-medium rounded-full">
                  {job.category}
                </span>
                <span className="px-3 py-1 bg-green-100 text-green-800 text-sm font-medium rounded-full">
                  {job.status}
                </span>
              </div>
              
              <div className="mb-8">
                <h2 className="text-lg font-semibold mb-4">Job Description</h2>
                <div className="prose max-w-none">
                  {job.description.split('\n\n').map((paragraph, index) => (
                    <p key={index} className="mb-4">{paragraph}</p>
                  ))}
                </div>
              </div>
              
              <div className="mb-8">
                <h2 className="text-lg font-semibold mb-4">Skills Required</h2>
                <div className="flex flex-wrap gap-2">
                  {job.skills.map(skill => (
                    <span key={skill} className="px-3 py-1 bg-gray-100 text-gray-800 text-sm font-medium rounded-full">
                      {skill}
                    </span>
                  ))}
                </div>
              </div>
              
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
                <div className="border rounded-lg p-4">
                  <div className="text-sm text-gray-500 mb-1">Budget</div>
                  <div className="text-xl font-semibold text-blue-600">{job.budget}</div>
                </div>
                <div className="border rounded-lg p-4">
                  <div className="text-sm text-gray-500 mb-1">Deadline</div>
                  <div className="text-xl font-semibold">{job.deadline}</div>
                </div>
              </div>
              
              <div className="border-t pt-6 mt-6">
                <button
                  onClick={() => setShowProposalForm(!showProposalForm)}
                  className="inline-flex items-center justify-center px-5 py-3 border border-transparent rounded-md shadow-sm text-base font-medium text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                >
                  {showProposalForm ? "Cancel Proposal" : "Submit a Proposal"}
                </button>
              </div>
            </div>
          </div>
          
          {/* Proposal Form */}
          {showProposalForm && (
            <div className="bg-white rounded-lg shadow overflow-hidden mb-8">
              <div className="p-6">
                <h2 className="text-xl font-bold mb-4">Submit Your Proposal</h2>
                <form onSubmit={handleSubmitProposal} className="space-y-6">
                  <div>
                    <label htmlFor="coverLetter" className="block text-sm font-medium text-gray-700 mb-1">
                      Cover Letter <span className="text-red-500">*</span>
                    </label>
                    <textarea
                      id="coverLetter"
                      name="coverLetter"
                      rows={6}
                      required
                      value={proposalData.coverLetter}
                      onChange={handleProposalChange}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                      placeholder="Introduce yourself and explain why you're the best fit for this job..."
                    ></textarea>
                  </div>
                  
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <div>
                      <label htmlFor="price" className="block text-sm font-medium text-gray-700 mb-1">
                        Your Price (RBTC) <span className="text-red-500">*</span>
                      </label>
                      <input
                        type="number"
                        id="price"
                        name="price"
                        required
                        min="0"
                        step="0.01"
                        value={proposalData.price}
                        onChange={handleProposalChange}
                        className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                        placeholder="e.g. 1500"
                      />
                    </div>
                    <div>
                      <label htmlFor="estimatedTime" className="block text-sm font-medium text-gray-700 mb-1">
                        Estimated Time (days) <span className="text-red-500">*</span>
                      </label>
                      <input
                        type="number"
                        id="estimatedTime"
                        name="estimatedTime"
                        required
                        min="1"
                        value={proposalData.estimatedTime}
                        onChange={handleProposalChange}
                        className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                        placeholder="e.g. 14"
                      />
                    </div>
                  </div>
                  
                  <div>
                    <label htmlFor="attachments" className="block text-sm font-medium text-gray-700 mb-1">
                      Attachments
                    </label>
                    <input
                      type="file"
                      id="attachments"
                      name="attachments"
                      onChange={handleFileChange}
                      multiple
                      className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                    />
                    <p className="mt-1 text-xs text-gray-500">Upload portfolio samples or other relevant documents (max 5MB each)</p>
                  </div>
                  
                  <div className="flex justify-end">
                    <button
                      type="submit"
                      disabled={isSubmitting}
                      className={`inline-flex items-center justify-center px-5 py-3 border border-transparent rounded-md shadow-sm text-base font-medium text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 ${
                        isSubmitting ? "opacity-75 cursor-not-allowed" : ""
                      }`}
                    >
                      {isSubmitting ? (
                        <>
                          <svg className="animate-spin -ml-1 mr-2 h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                            <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                            <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                          </svg>
                          Submitting...
                        </>
                      ) : (
                        "Submit Proposal"
                      )}
                    </button>
                  </div>
                </form>
              </div>
            </div>
          )}
        </div>
        
        {/* Sidebar */}
        <div className="lg:w-1/3">
          <div className="bg-white rounded-lg shadow overflow-hidden mb-6">
            <div className="p-6">
              <h2 className="text-lg font-semibold mb-4">About the Client</h2>
              <div className="mb-4">
                <div className="text-xl font-bold mb-1">{job.client.name}</div>
                <div className="flex items-center text-amber-500 mb-2">
                  <span className="mr-1">★</span>
                  <span className="text-gray-900">{job.client.rating}/5</span>
                </div>
              </div>
              
              <div className="space-y-3 text-sm">
                <div className="flex items-start">
                  <div className="flex-shrink-0 w-5 text-gray-500">
                    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-5 h-5">
                      <path d="M10.75 10.818v2.614A3.13 3.13 0 0011.888 13c.482-.315.612-.648.612-.875 0-.227-.13-.56-.612-.875a3.13 3.13 0 00-1.138-.432zM8.33 8.62c.053.055.115.11.184.164.208.16.46.284.736.363V6.603a2.45 2.45 0 00-.35.13c-.14.065-.27.143-.386.233-.377.292-.514.627-.514.909 0 .184.058.39.202.592.037.051.08.102.128.152z" />
                      <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-8-6a.75.75 0 01.75.75v.316a3.78 3.78 0 011.653.713c.426.33.744.74.925 1.2a.75.75 0 01-1.395.55 1.35 1.35 0 00-.447-.563 2.187 2.187 0 00-.736-.363V9.3c.698.093 1.383.32 1.959.696.787.514 1.29 1.27 1.29 2.13 0 .86-.504 1.616-1.29 2.13-.576.377-1.261.603-1.96.696v.299a.75.75 0 11-1.5 0v-.3c-.697-.092-1.382-.318-1.958-.695-.482-.315-.857-.717-1.078-1.188a.75.75 0 111.359-.636c.08.173.245.376.54.569.313.205.706.353 1.138.432v-2.748a3.782 3.782 0 01-1.653-.713C6.9 9.433 6.5 8.681 6.5 7.875c0-.805.4-1.558 1.097-2.096a3.78 3.78 0 011.653-.713V4.75A.75.75 0 0110 4z" clipRule="evenodd" />
                    </svg>
                  </div>
                  <div className="ml-3">
                    <span className="font-medium text-gray-900">Jobs Posted:</span> {job.client.jobsPosted}
                  </div>
                </div>
                <div className="flex items-start">
                  <div className="flex-shrink-0 w-5 text-gray-500">
                    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-5 h-5">
                      <path fillRule="evenodd" d="M9.69 18.933l.003.001C9.89 19.02 10 19 10 19s.11.02.308-.066l.002-.001.006-.003.018-.008a5.741 5.741 0 00.281-.14c.186-.096.446-.24.757-.433.62-.384 1.445-.966 2.274-1.765C15.302 14.988 17 12.493 17 9A7 7 0 103 9c0 3.492 1.698 5.988 3.355 7.584a13.731 13.731 0 002.273 1.765 11.842 11.842 0 00.976.544l.062.029.018.008.006.003zM10 11.25a2.25 2.25 0 100-4.5 2.25 2.25 0 000 4.5z" clipRule="evenodd" />
                    </svg>
                  </div>
                  <div className="ml-3">
                    <span className="font-medium text-gray-900">Location:</span> {job.client.location}
                  </div>
                </div>
                <div className="flex items-start">
                  <div className="flex-shrink-0 w-5 text-gray-500">
                    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-5 h-5">
                      <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm.75-13a.75.75 0 00-1.5 0v5c0 .414.336.75.75.75h4a.75.75 0 000-1.5h-3.25V5z" clipRule="evenodd" />
                    </svg>
                  </div>
                  <div className="ml-3">
                    <span className="font-medium text-gray-900">Member Since:</span> {job.client.memberSince}
                  </div>
                </div>
              </div>
            </div>
          </div>
          
          <div className="bg-white rounded-lg shadow overflow-hidden">
            <div className="p-6">
              <h2 className="text-lg font-semibold mb-4">Job Overview</h2>
              
              <div className="space-y-4 text-sm">
                <div className="flex items-start">
                  <div className="flex-shrink-0 w-5 text-gray-500">
                    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-5 h-5">
                      <path d="M10 8a3 3 0 100-6 3 3 0 000 6zM3.465 14.493a1.23 1.23 0 00.41 1.412A9.957 9.957 0 0010 18c2.31 0 4.438-.784 6.131-2.1.43-.333.604-.903.408-1.41a7.002 7.002 0 00-13.074.003z" />
                    </svg>
                  </div>
                  <div className="ml-3">
                    <span className="font-medium text-gray-900">Proposals:</span> {job.proposals}
                  </div>
                </div>
                <div className="flex items-start">
                  <div className="flex-shrink-0 w-5 text-gray-500">
                    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-5 h-5">
                      <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm.75-13a.75.75 0 00-1.5 0v5c0 .414.336.75.75.75h4a.75.75 0 000-1.5h-3.25V5z" clipRule="evenodd" />
                    </svg>
                  </div>
                  <div className="ml-3">
                    <span className="font-medium text-gray-900">Posted:</span> 3 days ago
                  </div>
                </div>
              </div>
              
              <div className="mt-6 pt-6 border-t">
                <Link
                  href="/jobs"
                  className="text-blue-600 hover:text-blue-800 font-medium flex items-center"
                >
                  <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 mr-1" viewBox="0 0 20 20" fill="currentColor">
                    <path fillRule="evenodd" d="M9.707 16.707a1 1 0 01-1.414 0l-6-6a1 1 0 010-1.414l6-6a1 1 0 011.414 1.414L5.414 9H17a1 1 0 110 2H5.414l4.293 4.293a1 1 0 010 1.414z" clipRule="evenodd" />
                  </svg>
                  Back to all jobs
                </Link>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
} 