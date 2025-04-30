// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title AIMatchingOracle
 * @dev Contract for AI-powered job matching for the GigFlow platform
 * This oracle receives matching data from off-chain AI algorithms and records them on-chain
 */
contract AIMatchingOracle is AccessControl, Pausable {
    // Role for AI service accounts that can update matches
    bytes32 public constant AI_PROVIDER_ROLE = keccak256("AI_PROVIDER_ROLE");
    
    // Role for admin accounts that can add/remove AI providers
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Address of the marketplace contract
    address public marketplaceAddress;
    
    // Mapping to store job-freelancer matches with scores
    // jobId => freelancer address => matching score (0-100)
    mapping(uint256 => mapping(address => uint256)) public jobMatches;
    
    // Mapping to store freelancer-job matches with scores
    // freelancer address => jobId => matching score (0-100)
    mapping(address => mapping(uint256 => uint256)) public freelancerMatches;
    
    // Top matches for each job (limited to 10 per job)
    // jobId => array of top matching freelancer addresses
    mapping(uint256 => address[]) public topJobMatches;
    
    // Top matches for each freelancer (limited to 10 per freelancer)
    // freelancer address => array of top matching job IDs
    mapping(address => uint256[]) public topFreelancerMatches;

    // Maximum number of top matches to keep
    uint256 public constant MAX_TOP_MATCHES = 10;

    // Events
    event JobMatchUpdated(uint256 indexed jobId, address indexed freelancer, uint256 score);
    event FreelancerMatchUpdated(address indexed freelancer, uint256 indexed jobId, uint256 score);
    event MarketplaceAddressUpdated(address indexed oldAddress, address indexed newAddress);
    event AIProviderAdded(address indexed provider);
    event AIProviderRemoved(address indexed provider);

    /**
     * @dev Constructor sets up initial roles
     * @param _admin Admin address that can manage AI providers
     */
    constructor(address _admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
    }

    /**
     * @dev Set the marketplace contract address
     * @param _marketplaceAddress Address of the GigFlow marketplace contract
     */
    function setMarketplaceAddress(address _marketplaceAddress) external onlyRole(ADMIN_ROLE) {
        require(_marketplaceAddress != address(0), "Invalid address");
        address oldAddress = marketplaceAddress;
        marketplaceAddress = _marketplaceAddress;
        emit MarketplaceAddressUpdated(oldAddress, _marketplaceAddress);
    }

    /**
     * @dev Add an AI provider that can update matching data
     * @param _provider Address of the AI provider
     */
    function addAIProvider(address _provider) external onlyRole(ADMIN_ROLE) {
        require(_provider != address(0), "Invalid address");
        _grantRole(AI_PROVIDER_ROLE, _provider);
        emit AIProviderAdded(_provider);
    }

    /**
     * @dev Remove an AI provider
     * @param _provider Address of the AI provider to remove
     */
    function removeAIProvider(address _provider) external onlyRole(ADMIN_ROLE) {
        require(hasRole(AI_PROVIDER_ROLE, _provider), "Not an AI provider");
        _revokeRole(AI_PROVIDER_ROLE, _provider);
        emit AIProviderRemoved(_provider);
    }

    /**
     * @dev Pause the contract functionality
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause the contract functionality
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @dev Update job matches for a batch of freelancers
     * @param _jobId ID of the job
     * @param _freelancers Array of freelancer addresses
     * @param _scores Array of matching scores (0-100)
     */
    function updateJobMatches(
        uint256 _jobId,
        address[] calldata _freelancers,
        uint256[] calldata _scores
    ) external onlyRole(AI_PROVIDER_ROLE) whenNotPaused {
        require(_freelancers.length == _scores.length, "Arrays length mismatch");
        require(_freelancers.length > 0, "Empty arrays");
        
        // Reset top matches for this job
        delete topJobMatches[_jobId];
        
        // Process each freelancer match
        for (uint256 i = 0; i < _freelancers.length; i++) {
            require(_freelancers[i] != address(0), "Invalid freelancer address");
            require(_scores[i] <= 100, "Score out of range");
            
            // Update job match score
            jobMatches[_jobId][_freelancers[i]] = _scores[i];
            
            // Update freelancer match score (bidirectional)
            freelancerMatches[_freelancers[i]][_jobId] = _scores[i];
            
            // Add to top matches if array is not full
            if (topJobMatches[_jobId].length < MAX_TOP_MATCHES) {
                topJobMatches[_jobId].push(_freelancers[i]);
            } else {
                // Find the lowest score in current top matches
                uint256 lowestIndex = 0;
                uint256 lowestScore = jobMatches[_jobId][topJobMatches[_jobId][0]];
                
                for (uint256 j = 1; j < MAX_TOP_MATCHES; j++) {
                    uint256 currentScore = jobMatches[_jobId][topJobMatches[_jobId][j]];
                    if (currentScore < lowestScore) {
                        lowestScore = currentScore;
                        lowestIndex = j;
                    }
                }
                
                // Replace if new score is higher than lowest score
                if (_scores[i] > lowestScore) {
                    topJobMatches[_jobId][lowestIndex] = _freelancers[i];
                }
            }
            
            // Update freelancer's top matches
            updateFreelancerTopMatches(_freelancers[i], _jobId, _scores[i]);
            
            emit JobMatchUpdated(_jobId, _freelancers[i], _scores[i]);
            emit FreelancerMatchUpdated(_freelancers[i], _jobId, _scores[i]);
        }
    }

    /**
     * @dev Update freelancer matches for a batch of jobs
     * @param _freelancer Address of the freelancer
     * @param _jobIds Array of job IDs
     * @param _scores Array of matching scores (0-100)
     */
    function updateFreelancerMatches(
        address _freelancer,
        uint256[] calldata _jobIds,
        uint256[] calldata _scores
    ) external onlyRole(AI_PROVIDER_ROLE) whenNotPaused {
        require(_jobIds.length == _scores.length, "Arrays length mismatch");
        require(_jobIds.length > 0, "Empty arrays");
        require(_freelancer != address(0), "Invalid freelancer address");
        
        // Reset top matches for this freelancer
        delete topFreelancerMatches[_freelancer];
        
        // Process each job match
        for (uint256 i = 0; i < _jobIds.length; i++) {
            require(_scores[i] <= 100, "Score out of range");
            
            // Update freelancer match score
            freelancerMatches[_freelancer][_jobIds[i]] = _scores[i];
            
            // Update job match score (bidirectional)
            jobMatches[_jobIds[i]][_freelancer] = _scores[i];
            
            // Add to top matches if array is not full
            if (topFreelancerMatches[_freelancer].length < MAX_TOP_MATCHES) {
                topFreelancerMatches[_freelancer].push(_jobIds[i]);
            } else {
                // Find the lowest score in current top matches
                uint256 lowestIndex = 0;
                uint256 lowestScore = freelancerMatches[_freelancer][topFreelancerMatches[_freelancer][0]];
                
                for (uint256 j = 1; j < MAX_TOP_MATCHES; j++) {
                    uint256 currentScore = freelancerMatches[_freelancer][topFreelancerMatches[_freelancer][j]];
                    if (currentScore < lowestScore) {
                        lowestScore = currentScore;
                        lowestIndex = j;
                    }
                }
                
                // Replace if new score is higher than lowest score
                if (_scores[i] > lowestScore) {
                    topFreelancerMatches[_freelancer][lowestIndex] = _jobIds[i];
                }
            }
            
            // Update job's top matches
            updateJobTopMatches(_jobIds[i], _freelancer, _scores[i]);
            
            emit JobMatchUpdated(_jobIds[i], _freelancer, _scores[i]);
            emit FreelancerMatchUpdated(_freelancer, _jobIds[i], _scores[i]);
        }
    }

    /**
     * @dev Helper function to update a freelancer's top matches
     * @param _freelancer Freelancer address
     * @param _jobId Job ID
     * @param _score Matching score
     */
    function updateFreelancerTopMatches(
        address _freelancer,
        uint256 _jobId,
        uint256 _score
    ) private {
        // Add to top matches if array is not full
        if (topFreelancerMatches[_freelancer].length < MAX_TOP_MATCHES) {
            // Check if job is already in top matches
            bool exists = false;
            for (uint256 i = 0; i < topFreelancerMatches[_freelancer].length; i++) {
                if (topFreelancerMatches[_freelancer][i] == _jobId) {
                    exists = true;
                    break;
                }
            }
            
            if (!exists) {
                topFreelancerMatches[_freelancer].push(_jobId);
            }
        } else {
            // Check if job is already in top matches
            bool exists = false;
            uint256 existingIndex = 0;
            
            for (uint256 i = 0; i < MAX_TOP_MATCHES; i++) {
                if (topFreelancerMatches[_freelancer][i] == _jobId) {
                    exists = true;
                    existingIndex = i;
                    break;
                }
            }
            
            if (!exists) {
                // Find the lowest score in current top matches
                uint256 lowestIndex = 0;
                uint256 lowestScore = freelancerMatches[_freelancer][topFreelancerMatches[_freelancer][0]];
                
                for (uint256 i = 1; i < MAX_TOP_MATCHES; i++) {
                    uint256 currentScore = freelancerMatches[_freelancer][topFreelancerMatches[_freelancer][i]];
                    if (currentScore < lowestScore) {
                        lowestScore = currentScore;
                        lowestIndex = i;
                    }
                }
                
                // Replace if new score is higher than lowest score
                if (_score > lowestScore) {
                    topFreelancerMatches[_freelancer][lowestIndex] = _jobId;
                }
            }
        }
    }

    /**
     * @dev Helper function to update a job's top matches
     * @param _jobId Job ID
     * @param _freelancer Freelancer address
     * @param _score Matching score
     */
    function updateJobTopMatches(
        uint256 _jobId,
        address _freelancer,
        uint256 _score
    ) private {
        // Add to top matches if array is not full
        if (topJobMatches[_jobId].length < MAX_TOP_MATCHES) {
            // Check if freelancer is already in top matches
            bool exists = false;
            for (uint256 i = 0; i < topJobMatches[_jobId].length; i++) {
                if (topJobMatches[_jobId][i] == _freelancer) {
                    exists = true;
                    break;
                }
            }
            
            if (!exists) {
                topJobMatches[_jobId].push(_freelancer);
            }
        } else {
            // Check if freelancer is already in top matches
            bool exists = false;
            uint256 existingIndex = 0;
            
            for (uint256 i = 0; i < MAX_TOP_MATCHES; i++) {
                if (topJobMatches[_jobId][i] == _freelancer) {
                    exists = true;
                    existingIndex = i;
                    break;
                }
            }
            
            if (!exists) {
                // Find the lowest score in current top matches
                uint256 lowestIndex = 0;
                uint256 lowestScore = jobMatches[_jobId][topJobMatches[_jobId][0]];
                
                for (uint256 i = 1; i < MAX_TOP_MATCHES; i++) {
                    uint256 currentScore = jobMatches[_jobId][topJobMatches[_jobId][i]];
                    if (currentScore < lowestScore) {
                        lowestScore = currentScore;
                        lowestIndex = i;
                    }
                }
                
                // Replace if new score is higher than lowest score
                if (_score > lowestScore) {
                    topJobMatches[_jobId][lowestIndex] = _freelancer;
                }
            }
        }
    }

    /**
     * @dev Get a job's matching score for a specific freelancer
     * @param _jobId Job ID
     * @param _freelancer Freelancer address
     * @return Matching score (0-100)
     */
    function getJobMatchScore(uint256 _jobId, address _freelancer) external view returns (uint256) {
        return jobMatches[_jobId][_freelancer];
    }

    /**
     * @dev Get a freelancer's matching score for a specific job
     * @param _freelancer Freelancer address
     * @param _jobId Job ID
     * @return Matching score (0-100)
     */
    function getFreelancerMatchScore(address _freelancer, uint256 _jobId) external view returns (uint256) {
        return freelancerMatches[_freelancer][_jobId];
    }

    /**
     * @dev Get top matching freelancers for a job
     * @param _jobId Job ID
     * @return Array of freelancer addresses
     */
    function getTopMatchesForJob(uint256 _jobId) external view returns (address[] memory) {
        return topJobMatches[_jobId];
    }

    /**
     * @dev Get top matching jobs for a freelancer
     * @param _freelancer Freelancer address
     * @return Array of job IDs
     */
    function getTopMatchesForFreelancer(address _freelancer) external view returns (uint256[] memory) {
        return topFreelancerMatches[_freelancer];
    }

    /**
     * @dev Get detailed match data for a job
     * @param _jobId Job ID
     * @return freelancers Array of freelancer addresses
     * @return scores Array of corresponding match scores
     */
    function getDetailedJobMatches(uint256 _jobId) external view returns (address[] memory freelancers, uint256[] memory scores) {
        address[] memory topFreelancers = topJobMatches[_jobId];
        uint256[] memory matchScores = new uint256[](topFreelancers.length);
        
        for (uint256 i = 0; i < topFreelancers.length; i++) {
            matchScores[i] = jobMatches[_jobId][topFreelancers[i]];
        }
        
        return (topFreelancers, matchScores);
    }

    /**
     * @dev Get detailed match data for a freelancer
     * @param _freelancer Freelancer address
     * @return jobIds Array of job IDs
     * @return scores Array of corresponding match scores
     */
    function getDetailedFreelancerMatches(address _freelancer) external view returns (uint256[] memory jobIds, uint256[] memory scores) {
        uint256[] memory topJobs = topFreelancerMatches[_freelancer];
        uint256[] memory matchScores = new uint256[](topJobs.length);
        
        for (uint256 i = 0; i < topJobs.length; i++) {
            matchScores[i] = freelancerMatches[_freelancer][topJobs[i]];
        }
        
        return (topJobs, matchScores);
    }
} 