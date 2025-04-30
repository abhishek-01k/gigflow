"use client";

import { useState } from "react";
import Link from "next/link";

type Job = {
  id: number;
  title: string;
  description: string;
  budget: string;
  deadline: string;
  skills: string[];
  client: {
    name: string;
    rating: number;
  };
};

export default function JobsPage() {
  // Sample job listings data (in a real app, this would come from an API)
  const [jobs, setJobs] = useState<Job[]>([
    {
      id: 1,
      title: "Develop Smart Contract for NFT Marketplace",
      description: "Looking for an experienced Solidity developer to create smart contracts for an NFT marketplace on Rootstock.",
      budget: "2000 RBTC",
      deadline: "30 days",
      skills: ["Solidity", "Smart Contracts", "NFT", "Rootstock"],
      client: {
        name: "CryptoInnovations",
        rating: 4.9
      }
    },
    {
      id: 2,
      title: "Frontend Developer for DeFi Dashboard",
      description: "Need a React developer to build a user-friendly dashboard for our DeFi application with Web3 integration.",
      budget: "3500 RBTC",
      deadline: "45 days",
      skills: ["React", "TypeScript", "Web3.js", "UI/UX"],
      client: {
        name: "DeFiSolutions",
        rating: 4.7
      }
    },
    {
      id: 3,
      title: "Blockchain Data Analyst",
      description: "Seeking an analyst to help us derive insights from blockchain data and create visualizations.",
      budget: "1800 RBTC",
      deadline: "20 days",
      skills: ["Data Analysis", "Python", "Visualization", "Blockchain"],
      client: {
        name: "DataChain",
        rating: 4.5
      }
    },
    {
      id: 4,
      title: "Smart Contract Auditor",
      description: "Need a security expert to audit our smart contracts for vulnerabilities before deployment.",
      budget: "4000 RBTC",
      deadline: "15 days",
      skills: ["Smart Contract Auditing", "Security", "Solidity", "Formal Verification"],
      client: {
        name: "SecureChain",
        rating: 5.0
      }
    },
    {
      id: 5,
      title: "Blockchain Technical Writer",
      description: "Looking for a technical writer to create documentation for our blockchain platform.",
      budget: "1200 RBTC",
      deadline: "25 days",
      skills: ["Technical Writing", "Blockchain", "Documentation", "Content Creation"],
      client: {
        name: "BlockDocs",
        rating: 4.6
      }
    }
  ]);

  const [filters, setFilters] = useState({
    searchTerm: "",
    skill: "",
    minBudget: "",
    maxBudget: ""
  });

  const handleFilterChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    setFilters(prev => ({ ...prev, [name]: value }));
  };

  // Filter jobs based on search criteria
  const filteredJobs = jobs.filter(job => {
    // Filter by search term
    if (filters.searchTerm && !job.title.toLowerCase().includes(filters.searchTerm.toLowerCase()) && 
        !job.description.toLowerCase().includes(filters.searchTerm.toLowerCase())) {
      return false;
    }
    
    // Filter by skill
    if (filters.skill && !job.skills.some(skill => skill.toLowerCase().includes(filters.skill.toLowerCase()))) {
      return false;
    }
    
    // Convert budget string to number for comparison
    const budgetValue = parseInt(job.budget.split(" ")[0]);
    
    // Filter by min budget
    if (filters.minBudget && budgetValue < parseInt(filters.minBudget)) {
      return false;
    }
    
    // Filter by max budget
    if (filters.maxBudget && budgetValue > parseInt(filters.maxBudget)) {
      return false;
    }
    
    return true;
  });

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center mb-8">
        <div>
          <h1 className="text-3xl font-bold mb-2">Available Jobs</h1>
          <p className="text-gray-600">Find your next opportunity in blockchain development</p>
        </div>
        <Link
          href="/jobs/create"
          className="mt-4 md:mt-0 inline-flex h-10 items-center justify-center rounded-md bg-blue-600 px-6 text-sm font-medium text-white shadow hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          Post a Job
        </Link>
      </div>

      {/* Filters */}
      <div className="bg-white rounded-lg shadow p-6 mb-8">
        <h2 className="text-lg font-semibold mb-4">Filters</h2>
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <div>
            <label htmlFor="searchTerm" className="block text-sm font-medium text-gray-700 mb-1">Search</label>
            <input
              type="text"
              id="searchTerm"
              name="searchTerm"
              value={filters.searchTerm}
              onChange={handleFilterChange}
              placeholder="Search jobs..."
              className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
            />
          </div>
          <div>
            <label htmlFor="skill" className="block text-sm font-medium text-gray-700 mb-1">Skill</label>
            <input
              type="text"
              id="skill"
              name="skill"
              value={filters.skill}
              onChange={handleFilterChange}
              placeholder="e.g. Solidity"
              className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
            />
          </div>
          <div>
            <label htmlFor="minBudget" className="block text-sm font-medium text-gray-700 mb-1">Min Budget</label>
            <input
              type="number"
              id="minBudget"
              name="minBudget"
              value={filters.minBudget}
              onChange={handleFilterChange}
              placeholder="Min RBTC"
              className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
            />
          </div>
          <div>
            <label htmlFor="maxBudget" className="block text-sm font-medium text-gray-700 mb-1">Max Budget</label>
            <input
              type="number"
              id="maxBudget"
              name="maxBudget"
              value={filters.maxBudget}
              onChange={handleFilterChange}
              placeholder="Max RBTC"
              className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
            />
          </div>
        </div>
      </div>

      {/* Job Listings */}
      <div className="space-y-6">
        {filteredJobs.length > 0 ? (
          filteredJobs.map(job => (
            <div key={job.id} className="bg-white rounded-lg shadow overflow-hidden">
              <div className="p-6">
                <div className="flex justify-between items-start">
                  <h2 className="text-xl font-bold text-gray-900 mb-2">{job.title}</h2>
                  <span className="text-lg font-semibold text-blue-600">{job.budget}</span>
                </div>
                <p className="text-gray-600 mb-4">{job.description}</p>
                <div className="flex flex-wrap gap-2 mb-4">
                  {job.skills.map(skill => (
                    <span key={skill} className="px-2 py-1 bg-blue-100 text-blue-800 text-xs font-medium rounded">
                      {skill}
                    </span>
                  ))}
                </div>
                <div className="flex justify-between items-center">
                  <div className="text-gray-600 text-sm">
                    <span className="font-medium">Client:</span> {job.client.name} 
                    <span className="ml-2 inline-flex items-center">
                      <span className="text-amber-500 mr-1">★</span> 
                      {job.client.rating}
                    </span>
                  </div>
                  <div className="text-gray-600 text-sm">
                    <span className="font-medium">Deadline:</span> {job.deadline}
                  </div>
                </div>
                <div className="mt-4 flex justify-end">
                  <Link
                    href={`/jobs/${job.id}`}
                    className="inline-flex items-center justify-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                  >
                    View Details
                  </Link>
                </div>
              </div>
            </div>
          ))
        ) : (
          <div className="text-center py-12 bg-white rounded-lg shadow">
            <svg
              className="mx-auto h-12 w-12 text-gray-400"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
              xmlns="http://www.w3.org/2000/svg"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
            <h3 className="mt-2 text-lg font-medium text-gray-900">No jobs found</h3>
            <p className="mt-1 text-gray-500">Try adjusting your search filters.</p>
          </div>
        )}
      </div>
    </div>
  );
} 