// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title AISkillVerifier
 * @dev Contract for AI-powered skill verification for the GigFlow platform
 * This oracle receives skill verification data from off-chain AI algorithms and records them on-chain
 */
contract AISkillVerifier is AccessControl, Pausable {
    using Counters for Counters.Counter;
    
    // Role for AI service accounts that can update verifications
    bytes32 public constant AI_VERIFIER_ROLE = keccak256("AI_VERIFIER_ROLE");
    
    // Role for admin accounts that can update parameters
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    // Address of the marketplace contract
    address public marketplaceAddress;
    
    // Counter for skill verification IDs
    Counters.Counter private _verificationIdCounter;
    
    // Struct for skill verification
    struct SkillVerification {
        uint256 id;
        address freelancer;
        string skillName;
        uint256 score; // 0-100 score
        string proofHash; // IPFS hash of verification proof
        uint256 verificationDate;
        uint256 expiryDate; // When verification expires and needs renewal
        bool isExpired;
    }
    
    // Mapping freelancer address => skill name => verification ID
    mapping(address => mapping(string => uint256)) public freelancerSkillVerifications;
    
    // Mapping verification ID => SkillVerification
    mapping(uint256 => SkillVerification) public verifications;
    
    // Mapping freelancer address => array of verification IDs
    mapping(address => uint256[]) public freelancerVerifications;
    
    // Mapping skill name => array of freelancer addresses (for discovery)
    mapping(string => address[]) public skillFreelancers;
    
    // Skill verification validity period (default 180 days)
    uint256 public verificationValidityPeriod = 180 days;
    
    // Events
    event SkillVerified(uint256 indexed verificationId, address indexed freelancer, string skillName, uint256 score);
    event VerificationExpired(uint256 indexed verificationId, address indexed freelancer, string skillName);
    event VerificationRenewed(uint256 indexed verificationId, address indexed freelancer, string skillName, uint256 newScore);
    event MarketplaceAddressUpdated(address indexed oldAddress, address indexed newAddress);
    event AIVerifierAdded(address indexed verifier);
    event AIVerifierRemoved(address indexed verifier);
    event ValidityPeriodUpdated(uint256 oldPeriod, uint256 newPeriod);
    
    /**
     * @dev Constructor sets up initial admin role
     * @param _admin Admin address that can manage verifiers
     */
    constructor(address _admin) {
        require(_admin != address(0), "Invalid admin address");
        
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
     * @dev Add an AI verifier that can update skill verification data
     * @param _verifier Address of the AI verifier
     */
    function addAIVerifier(address _verifier) external onlyRole(ADMIN_ROLE) {
        require(_verifier != address(0), "Invalid address");
        _grantRole(AI_VERIFIER_ROLE, _verifier);
        emit AIVerifierAdded(_verifier);
    }
    
    /**
     * @dev Remove an AI verifier
     * @param _verifier Address of the AI verifier to remove
     */
    function removeAIVerifier(address _verifier) external onlyRole(ADMIN_ROLE) {
        require(hasRole(AI_VERIFIER_ROLE, _verifier), "Not an AI verifier");
        _revokeRole(AI_VERIFIER_ROLE, _verifier);
        emit AIVerifierRemoved(_verifier);
    }
    
    /**
     * @dev Update the validity period for skill verifications
     * @param _validityPeriod New validity period in seconds
     */
    function updateValidityPeriod(uint256 _validityPeriod) external onlyRole(ADMIN_ROLE) {
        require(_validityPeriod >= 30 days, "Validity period too short");
        require(_validityPeriod <= 730 days, "Validity period too long");
        
        uint256 oldPeriod = verificationValidityPeriod;
        verificationValidityPeriod = _validityPeriod;
        emit ValidityPeriodUpdated(oldPeriod, _validityPeriod);
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
     * @dev Verify a skill for a freelancer
     * @param _freelancer Freelancer address
     * @param _skillName Name of the skill
     * @param _score Verification score (0-100)
     * @param _proofHash IPFS hash with verification proof
     */
    function verifySkill(
        address _freelancer,
        string calldata _skillName,
        uint256 _score,
        string calldata _proofHash
    ) external onlyRole(AI_VERIFIER_ROLE) whenNotPaused {
        require(_freelancer != address(0), "Invalid freelancer address");
        require(bytes(_skillName).length > 0, "Invalid skill name");
        require(_score <= 100, "Score out of range");
        require(bytes(_proofHash).length > 0, "Proof hash required");
        
        // Check if skill is already verified
        uint256 existingVerificationId = freelancerSkillVerifications[_freelancer][_skillName];
        
        if (existingVerificationId > 0) {
            // Existing verification found, renew it
            _renewSkillVerification(existingVerificationId, _score, _proofHash);
        } else {
            // New verification
            _createNewSkillVerification(_freelancer, _skillName, _score, _proofHash);
        }
    }
    
    /**
     * @dev Bulk verify skills for a freelancer
     * @param _freelancer Freelancer address
     * @param _skillNames Array of skill names
     * @param _scores Array of verification scores (0-100)
     * @param _proofHashes Array of IPFS hashes with verification proofs
     */
    function bulkVerifySkills(
        address _freelancer,
        string[] calldata _skillNames,
        uint256[] calldata _scores,
        string[] calldata _proofHashes
    ) external onlyRole(AI_VERIFIER_ROLE) whenNotPaused {
        require(_freelancer != address(0), "Invalid freelancer address");
        require(_skillNames.length > 0, "Empty skill names array");
        require(_skillNames.length == _scores.length, "Arrays length mismatch");
        require(_skillNames.length == _proofHashes.length, "Arrays length mismatch");
        
        for (uint256 i = 0; i < _skillNames.length; i++) {
            require(bytes(_skillNames[i]).length > 0, "Invalid skill name");
            require(_scores[i] <= 100, "Score out of range");
            require(bytes(_proofHashes[i]).length > 0, "Proof hash required");
            
            // Check if skill is already verified
            uint256 existingVerificationId = freelancerSkillVerifications[_freelancer][_skillNames[i]];
            
            if (existingVerificationId > 0) {
                // Existing verification found, renew it
                _renewSkillVerification(existingVerificationId, _scores[i], _proofHashes[i]);
            } else {
                // New verification
                _createNewSkillVerification(_freelancer, _skillNames[i], _scores[i], _proofHashes[i]);
            }
        }
    }
    
    /**
     * @dev Mark a verification as expired
     * @param _verificationId Verification ID
     */
    function expireVerification(uint256 _verificationId) external onlyRole(AI_VERIFIER_ROLE) {
        require(_verificationId > 0 && _verificationId <= _verificationIdCounter.current(), "Invalid verification ID");
        
        SkillVerification storage verification = verifications[_verificationId];
        require(!verification.isExpired, "Already expired");
        
        verification.isExpired = true;
        emit VerificationExpired(_verificationId, verification.freelancer, verification.skillName);
    }
    
    /**
     * @dev Check if any verifications have expired and mark them as such
     * @param _verificationIds Array of verification IDs to check
     */
    function checkExpiredVerifications(uint256[] calldata _verificationIds) external {
        for (uint256 i = 0; i < _verificationIds.length; i++) {
            uint256 verificationId = _verificationIds[i];
            
            if (verificationId > 0 && verificationId <= _verificationIdCounter.current()) {
                SkillVerification storage verification = verifications[verificationId];
                
                if (!verification.isExpired && verification.expiryDate < block.timestamp) {
                    verification.isExpired = true;
                    emit VerificationExpired(verificationId, verification.freelancer, verification.skillName);
                }
            }
        }
    }
    
    /**
     * @dev Internal function to create a new skill verification
     * @param _freelancer Freelancer address
     * @param _skillName Name of the skill
     * @param _score Verification score (0-100)
     * @param _proofHash IPFS hash with verification proof
     */
    function _createNewSkillVerification(
        address _freelancer,
        string calldata _skillName,
        uint256 _score,
        string calldata _proofHash
    ) internal {
        _verificationIdCounter.increment();
        uint256 newVerificationId = _verificationIdCounter.current();
        
        // Create new verification
        verifications[newVerificationId] = SkillVerification({
            id: newVerificationId,
            freelancer: _freelancer,
            skillName: _skillName,
            score: _score,
            proofHash: _proofHash,
            verificationDate: block.timestamp,
            expiryDate: block.timestamp + verificationValidityPeriod,
            isExpired: false
        });
        
        // Update mappings
        freelancerSkillVerifications[_freelancer][_skillName] = newVerificationId;
        freelancerVerifications[_freelancer].push(newVerificationId);
        
        // Add to skill-based discovery
        bool alreadyListed = false;
        for (uint256 i = 0; i < skillFreelancers[_skillName].length; i++) {
            if (skillFreelancers[_skillName][i] == _freelancer) {
                alreadyListed = true;
                break;
            }
        }
        
        if (!alreadyListed) {
            skillFreelancers[_skillName].push(_freelancer);
        }
        
        emit SkillVerified(newVerificationId, _freelancer, _skillName, _score);
    }
    
    /**
     * @dev Internal function to renew an existing skill verification
     * @param _verificationId Verification ID
     * @param _score New verification score (0-100)
     * @param _proofHash New IPFS hash with verification proof
     */
    function _renewSkillVerification(
        uint256 _verificationId,
        uint256 _score,
        string calldata _proofHash
    ) internal {
        SkillVerification storage verification = verifications[_verificationId];
        
        // Update verification details
        verification.score = _score;
        verification.proofHash = _proofHash;
        verification.verificationDate = block.timestamp;
        verification.expiryDate = block.timestamp + verificationValidityPeriod;
        verification.isExpired = false;
        
        emit VerificationRenewed(_verificationId, verification.freelancer, verification.skillName, _score);
    }
    
    /**
     * @dev Get verification details
     * @param _verificationId Verification ID
     * @return Verification details
     */
    function getVerification(uint256 _verificationId) external view returns (SkillVerification memory) {
        require(_verificationId > 0 && _verificationId <= _verificationIdCounter.current(), "Invalid verification ID");
        return verifications[_verificationId];
    }
    
    /**
     * @dev Get a freelancer's verification for a specific skill
     * @param _freelancer Freelancer address
     * @param _skillName Skill name
     * @return Verification details
     */
    function getFreelancerSkillVerification(address _freelancer, string calldata _skillName) 
        external 
        view 
        returns (SkillVerification memory) 
    {
        uint256 verificationId = freelancerSkillVerifications[_freelancer][_skillName];
        require(verificationId > 0, "No verification found");
        
        return verifications[verificationId];
    }
    
    /**
     * @dev Get all verification IDs for a freelancer
     * @param _freelancer Freelancer address
     * @return Array of verification IDs
     */
    function getAllFreelancerVerifications(address _freelancer) external view returns (uint256[] memory) {
        return freelancerVerifications[_freelancer];
    }
    
    /**
     * @dev Get all verified skills for a freelancer
     * @param _freelancer Freelancer address
     * @return skillNames Array of skill names
     * @return scores Array of scores
     * @return expiryDates Array of expiry dates
     * @return isExpired Array of expiry status
     */
    function getFreelancerSkills(address _freelancer) 
        external 
        view 
        returns (
            string[] memory skillNames,
            uint256[] memory scores,
            uint256[] memory expiryDates,
            bool[] memory isExpired
        ) 
    {
        uint256[] memory verificationIds = freelancerVerifications[_freelancer];
        uint256 verificationCount = verificationIds.length;
        
        skillNames = new string[](verificationCount);
        scores = new uint256[](verificationCount);
        expiryDates = new uint256[](verificationCount);
        isExpired = new bool[](verificationCount);
        
        for (uint256 i = 0; i < verificationCount; i++) {
            SkillVerification memory verification = verifications[verificationIds[i]];
            skillNames[i] = verification.skillName;
            scores[i] = verification.score;
            expiryDates[i] = verification.expiryDate;
            isExpired[i] = verification.isExpired;
        }
        
        return (skillNames, scores, expiryDates, isExpired);
    }
    
    /**
     * @dev Get all freelancers with a specific skill
     * @param _skillName Skill name
     * @return Array of freelancer addresses
     */
    function getFreelancersWithSkill(string calldata _skillName) external view returns (address[] memory) {
        return skillFreelancers[_skillName];
    }
    
    /**
     * @dev Get top freelancers with a specific skill sorted by score
     * @param _skillName Skill name
     * @param _limit Maximum number of results
     * @return freelancers Array of freelancer addresses
     * @return scores Array of scores
     */
    function getTopFreelancersWithSkill(string calldata _skillName, uint256 _limit) 
        external 
        view 
        returns (address[] memory freelancers, uint256[] memory scores) 
    {
        address[] memory allFreelancers = skillFreelancers[_skillName];
        uint256 resultCount = _limit < allFreelancers.length ? _limit : allFreelancers.length;
        
        if (resultCount == 0) {
            return (new address[](0), new uint256[](0));
        }
        
        // Create freelancers and scores arrays
        freelancers = new address[](resultCount);
        scores = new uint256[](resultCount);
        
        // Get scores for all freelancers
        address[] memory tempFreelancers = new address[](allFreelancers.length);
        uint256[] memory tempScores = new uint256[](allFreelancers.length);
        
        for (uint256 i = 0; i < allFreelancers.length; i++) {
            tempFreelancers[i] = allFreelancers[i];
            tempScores[i] = verifications[freelancerSkillVerifications[allFreelancers[i]][_skillName]].score;
        }
        
        // Sort by score (simple bubble sort)
        for (uint256 i = 0; i < allFreelancers.length; i++) {
            for (uint256 j = 0; j < allFreelancers.length - i - 1; j++) {
                if (tempScores[j] < tempScores[j + 1]) {
                    // Swap scores
                    uint256 tempScore = tempScores[j];
                    tempScores[j] = tempScores[j + 1];
                    tempScores[j + 1] = tempScore;
                    
                    // Swap freelancers
                    address tempFreelancer = tempFreelancers[j];
                    tempFreelancers[j] = tempFreelancers[j + 1];
                    tempFreelancers[j + 1] = tempFreelancer;
                }
            }
        }
        
        // Take top results
        for (uint256 i = 0; i < resultCount; i++) {
            freelancers[i] = tempFreelancers[i];
            scores[i] = tempScores[i];
        }
        
        return (freelancers, scores);
    }
} 