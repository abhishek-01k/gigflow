// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

interface IGigFlowMarketplace {
    enum JobStatus { Open, InProgress, Completed, Cancelled }
    
    function getJob(uint256 _jobId) external view returns (
        uint256 id,
        address client,
        string memory title,
        string memory description,
        string memory ipfsHash,
        uint256 budget,
        uint256 deadline,
        JobStatus status,
        uint256 dateCreated,
        string[] memory requiredSkills,
        address assignedFreelancer,
        uint256 acceptedProposalId
    );
}

/**
 * @title GigFlowDisputeResolver
 * @dev Contract for handling disputes between freelancers and clients
 * Supports both automatic (AI-driven) and manual (DAO-based) dispute resolution
 */
contract GigFlowDisputeResolver is AccessControl, ReentrancyGuard {
    using Counters for Counters.Counter;
    
    // Roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant RESOLVER_ROLE = keccak256("RESOLVER_ROLE");
    bytes32 public constant AI_RESOLVER_ROLE = keccak256("AI_RESOLVER_ROLE");
    
    // Resolution methods
    enum ResolutionMethod { Pending, Auto, Manual, Mediated }
    
    // Dispute status
    enum DisputeStatus { 
        Created,      // Dispute has been created
        InProgress,   // Dispute is being reviewed
        Resolved,     // Dispute has been resolved
        Cancelled     // Dispute has been cancelled
    }
    
    // Dispute struct
    struct Dispute {
        uint256 id;
        uint256 jobId;
        address client;
        address freelancer;
        string clientEvidence;    // IPFS hash of client evidence
        string freelancerEvidence; // IPFS hash of freelancer evidence
        uint256 amount;          // Amount in dispute
        uint256 creationTime;
        uint256 resolutionTime;
        DisputeStatus status;
        ResolutionMethod resolutionMethod;
        address resolver;         // Address of the resolver (if manual)
        uint256 clientAward;      // Amount awarded to client
        uint256 freelancerAward;  // Amount awarded to freelancer
        uint256 platformFee;      // Fee taken by platform
        string resolution;        // IPFS hash containing resolution details
    }
    
    // Connection to marketplace
    address public marketplaceAddress;
    IGigFlowMarketplace private marketplace;
    
    // Counter for dispute IDs
    Counters.Counter private _disputeIdCounter;
    
    // Resolution timeframe
    uint256 public autoResolutionTimeframe = 2 days; // Time for automatic resolution
    uint256 public manualResolutionTimeframe = 7 days; // Time for manual resolution
    
    // Escrow for disputes
    mapping(uint256 => uint256) public disputeEscrows; // disputeId => amount
    
    // Dispute mappings
    mapping(uint256 => Dispute) public disputes; // disputeId => Dispute
    mapping(uint256 => bool) public jobHasDispute; // jobId => has active dispute
    mapping(address => uint256[]) public clientDisputes; // client => disputeIds
    mapping(address => uint256[]) public freelancerDisputes; // freelancer => disputeIds
    mapping(address => uint256[]) public resolverDisputes; // resolver => disputeIds
    
    // Voting for manual resolution
    mapping(uint256 => mapping(address => bool)) public hasVoted; // disputeId => resolver => has voted
    mapping(uint256 => uint256) public votesForClient; // disputeId => votes for client
    mapping(uint256 => uint256) public votesForFreelancer; // disputeId => votes for freelancer
    mapping(uint256 => uint256) public totalVotes; // disputeId => total votes
    uint256 public minVotesRequired = 3; // Minimum votes required to resolve
    
    // Events
    event DisputeCreated(uint256 indexed disputeId, uint256 indexed jobId, address indexed initiator, uint256 amount);
    event EvidenceSubmitted(uint256 indexed disputeId, address indexed submitter, string evidenceHash);
    event DisputeResolved(uint256 indexed disputeId, ResolutionMethod method, address resolver, uint256 clientAward, uint256 freelancerAward);
    event DisputeCancelled(uint256 indexed disputeId, address indexed canceller);
    event ResolverVoted(uint256 indexed disputeId, address indexed resolver, bool votedForClient);
    event DisputeEscrowFunded(uint256 indexed disputeId, uint256 amount);
    event DisputeEscrowReleased(uint256 indexed disputeId, address indexed recipient, uint256 amount);
    event AutoResolutionTimeframeUpdated(uint256 oldTimeframe, uint256 newTimeframe);
    event ManualResolutionTimeframeUpdated(uint256 oldTimeframe, uint256 newTimeframe);
    event MinVotesRequiredUpdated(uint256 oldMinVotes, uint256 newMinVotes);
    event MarketplaceAddressUpdated(address indexed oldAddress, address indexed newAddress);
    
    /**
     * @dev Constructor sets up initial roles and marketplace address
     * @param _admin Admin address
     * @param _marketplaceAddress Address of GigFlowMarketplace
     */
    constructor(address _admin, address _marketplaceAddress) {
        require(_admin != address(0), "Invalid admin address");
        require(_marketplaceAddress != address(0), "Invalid marketplace address");
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        
        marketplaceAddress = _marketplaceAddress;
        marketplace = IGigFlowMarketplace(_marketplaceAddress);
    }
    
    /**
     * @dev Set the marketplace address
     * @param _marketplaceAddress Address of GigFlowMarketplace
     */
    function setMarketplaceAddress(address _marketplaceAddress) external onlyRole(ADMIN_ROLE) {
        require(_marketplaceAddress != address(0), "Invalid marketplace address");
        address oldAddress = marketplaceAddress;
        marketplaceAddress = _marketplaceAddress;
        marketplace = IGigFlowMarketplace(_marketplaceAddress);
        emit MarketplaceAddressUpdated(oldAddress, _marketplaceAddress);
    }
    
    /**
     * @dev Set the auto resolution timeframe
     * @param _timeframe New timeframe in seconds
     */
    function setAutoResolutionTimeframe(uint256 _timeframe) external onlyRole(ADMIN_ROLE) {
        require(_timeframe >= 1 days, "Timeframe too short");
        require(_timeframe <= 14 days, "Timeframe too long");
        uint256 oldTimeframe = autoResolutionTimeframe;
        autoResolutionTimeframe = _timeframe;
        emit AutoResolutionTimeframeUpdated(oldTimeframe, _timeframe);
    }
    
    /**
     * @dev Set the manual resolution timeframe
     * @param _timeframe New timeframe in seconds
     */
    function setManualResolutionTimeframe(uint256 _timeframe) external onlyRole(ADMIN_ROLE) {
        require(_timeframe >= 3 days, "Timeframe too short");
        require(_timeframe <= 30 days, "Timeframe too long");
        uint256 oldTimeframe = manualResolutionTimeframe;
        manualResolutionTimeframe = _timeframe;
        emit ManualResolutionTimeframeUpdated(oldTimeframe, _timeframe);
    }
    
    /**
     * @dev Set the minimum votes required for manual resolution
     * @param _minVotes New minimum votes required
     */
    function setMinVotesRequired(uint256 _minVotes) external onlyRole(ADMIN_ROLE) {
        require(_minVotes >= 1, "Min votes too low");
        require(_minVotes <= 10, "Min votes too high");
        uint256 oldMinVotes = minVotesRequired;
        minVotesRequired = _minVotes;
        emit MinVotesRequiredUpdated(oldMinVotes, _minVotes);
    }
    
    /**
     * @dev Add a resolver with permission to resolve disputes
     * @param _resolver Address of the resolver
     */
    function addResolver(address _resolver) external onlyRole(ADMIN_ROLE) {
        require(_resolver != address(0), "Invalid resolver address");
        _grantRole(RESOLVER_ROLE, _resolver);
    }
    
    /**
     * @dev Remove a resolver
     * @param _resolver Address of the resolver to remove
     */
    function removeResolver(address _resolver) external onlyRole(ADMIN_ROLE) {
        require(hasRole(RESOLVER_ROLE, _resolver), "Not a resolver");
        _revokeRole(RESOLVER_ROLE, _resolver);
    }
    
    /**
     * @dev Add an AI resolver with permission to automatically resolve disputes
     * @param _aiResolver Address of the AI resolver
     */
    function addAIResolver(address _aiResolver) external onlyRole(ADMIN_ROLE) {
        require(_aiResolver != address(0), "Invalid AI resolver address");
        _grantRole(AI_RESOLVER_ROLE, _aiResolver);
    }
    
    /**
     * @dev Remove an AI resolver
     * @param _aiResolver Address of the AI resolver to remove
     */
    function removeAIResolver(address _aiResolver) external onlyRole(ADMIN_ROLE) {
        require(hasRole(AI_RESOLVER_ROLE, _aiResolver), "Not an AI resolver");
        _revokeRole(AI_RESOLVER_ROLE, _aiResolver);
    }
    
    /**
     * @dev Create a new dispute
     * @param _jobId ID of the job in dispute
     * @param _evidence IPFS hash containing evidence
     * @param _preferredMethod Preferred resolution method (1 for Auto, 2 for Manual, 3 for Mediated)
     */
    function createDispute(
        uint256 _jobId,
        string calldata _evidence,
        uint8 _preferredMethod
    ) external payable nonReentrant {
        // Get job details from marketplace
        (
            uint256 id,
            address client,
            , // title
            , // description
            , // ipfsHash
            uint256 budget,
            , // deadline
            IGigFlowMarketplace.JobStatus status,
            , // dateCreated
            , // requiredSkills
            address freelancer,
            // acceptedProposalId
        ) = marketplace.getJob(_jobId);
        
        require(id == _jobId, "Job does not exist");
        require(status == IGigFlowMarketplace.JobStatus.InProgress, "Job not in progress");
        require(msg.sender == client || msg.sender == freelancer, "Not involved in job");
        require(!jobHasDispute[_jobId], "Dispute already exists");
        require(bytes(_evidence).length > 0, "Evidence required");
        require(_preferredMethod >= 1 && _preferredMethod <= 3, "Invalid resolution method");
        
        // Create new dispute
        _disputeIdCounter.increment();
        uint256 newDisputeId = _disputeIdCounter.current();
        
        // Determine resolution method
        ResolutionMethod resolutionMethod = ResolutionMethod(_preferredMethod);
        
        // Create the dispute object
        disputes[newDisputeId] = Dispute({
            id: newDisputeId,
            jobId: _jobId,
            client: client,
            freelancer: freelancer,
            clientEvidence: msg.sender == client ? _evidence : "",
            freelancerEvidence: msg.sender == freelancer ? _evidence : "",
            amount: budget,
            creationTime: block.timestamp,
            resolutionTime: 0,
            status: DisputeStatus.Created,
            resolutionMethod: resolutionMethod,
            resolver: address(0),
            clientAward: 0,
            freelancerAward: 0,
            platformFee: 0,
            resolution: ""
        });
        
        // Update mappings
        jobHasDispute[_jobId] = true;
        clientDisputes[client].push(newDisputeId);
        freelancerDisputes[freelancer].push(newDisputeId);
        
        // Fund dispute escrow
        disputeEscrows[newDisputeId] = msg.value;
        
        // Update dispute status
        disputes[newDisputeId].status = DisputeStatus.InProgress;
        
        // Emit events
        emit DisputeCreated(newDisputeId, _jobId, msg.sender, budget);
        emit EvidenceSubmitted(newDisputeId, msg.sender, _evidence);
        if (msg.value > 0) {
            emit DisputeEscrowFunded(newDisputeId, msg.value);
        }
    }
    
    /**
     * @dev Submit evidence for a dispute
     * @param _disputeId ID of the dispute
     * @param _evidence IPFS hash containing evidence
     */
    function submitEvidence(uint256 _disputeId, string calldata _evidence) external {
        require(_disputeId > 0 && _disputeId <= _disputeIdCounter.current(), "Invalid dispute ID");
        Dispute storage dispute = disputes[_disputeId];
        
        require(msg.sender == dispute.client || msg.sender == dispute.freelancer, "Not involved in dispute");
        require(dispute.status == DisputeStatus.InProgress, "Dispute not in progress");
        require(bytes(_evidence).length > 0, "Evidence required");
        
        // Update evidence
        if (msg.sender == dispute.client) {
            dispute.clientEvidence = _evidence;
        } else {
            dispute.freelancerEvidence = _evidence;
        }
        
        emit EvidenceSubmitted(_disputeId, msg.sender, _evidence);
    }
    
    /**
     * @dev Add funds to the dispute escrow
     * @param _disputeId ID of the dispute
     */
    function fundDispute(uint256 _disputeId) external payable nonReentrant {
        require(_disputeId > 0 && _disputeId <= _disputeIdCounter.current(), "Invalid dispute ID");
        Dispute storage dispute = disputes[_disputeId];
        
        require(msg.sender == dispute.client || msg.sender == dispute.freelancer, "Not involved in dispute");
        require(dispute.status == DisputeStatus.InProgress, "Dispute not in progress");
        require(msg.value > 0, "Must send funds");
        
        // Add funds to escrow
        disputeEscrows[_disputeId] += msg.value;
        
        emit DisputeEscrowFunded(_disputeId, msg.value);
    }
    
    /**
     * @dev Cancel a dispute
     * @param _disputeId ID of the dispute to cancel
     */
    function cancelDispute(uint256 _disputeId) external nonReentrant {
        require(_disputeId > 0 && _disputeId <= _disputeIdCounter.current(), "Invalid dispute ID");
        Dispute storage dispute = disputes[_disputeId];
        
        require(
            msg.sender == dispute.client || 
            msg.sender == dispute.freelancer ||
            hasRole(ADMIN_ROLE, msg.sender),
            "Not authorized"
        );
        require(dispute.status == DisputeStatus.InProgress, "Dispute not in progress");
        
        // Update dispute status
        dispute.status = DisputeStatus.Cancelled;
        dispute.resolutionTime = block.timestamp;
        
        // Remove job dispute flag
        jobHasDispute[dispute.jobId] = false;
        
        // Refund escrow if any
        uint256 escrowAmount = disputeEscrows[_disputeId];
        if (escrowAmount > 0) {
            address recipient = dispute.client; // Default to client
            disputeEscrows[_disputeId] = 0;
            
            (bool success, ) = recipient.call{value: escrowAmount}("");
            require(success, "Refund failed");
            
            emit DisputeEscrowReleased(_disputeId, recipient, escrowAmount);
        }
        
        emit DisputeCancelled(_disputeId, msg.sender);
    }
    
    /**
     * @dev Resolve a dispute automatically (AI resolver)
     * @param _disputeId ID of the dispute
     * @param _clientAward Amount awarded to client
     * @param _freelancerAward Amount awarded to freelancer
     * @param _platformFee Fee taken by platform
     * @param _resolution IPFS hash with resolution details
     */
    function resolveDisputeAuto(
        uint256 _disputeId,
        uint256 _clientAward,
        uint256 _freelancerAward,
        uint256 _platformFee,
        string calldata _resolution
    ) external onlyRole(AI_RESOLVER_ROLE) nonReentrant {
        require(_disputeId > 0 && _disputeId <= _disputeIdCounter.current(), "Invalid dispute ID");
        Dispute storage dispute = disputes[_disputeId];
        
        require(dispute.status == DisputeStatus.InProgress, "Dispute not in progress");
        require(dispute.resolutionMethod == ResolutionMethod.Auto, "Not auto resolution");
        require(
            _clientAward + _freelancerAward + _platformFee <= dispute.amount,
            "Awards exceed dispute amount"
        );
        require(bytes(_resolution).length > 0, "Resolution required");
        
        // Process resolution
        _processResolution(
            _disputeId,
            ResolutionMethod.Auto,
            msg.sender,
            _clientAward,
            _freelancerAward,
            _platformFee,
            _resolution
        );
    }
    
    /**
     * @dev Vote on a manual dispute resolution
     * @param _disputeId ID of the dispute
     * @param _voteForClient True if voting for client, false for freelancer
     * @param _clientAwardPercent Percentage of funds to award to client (0-100)
     */
    function voteOnDispute(
        uint256 _disputeId,
        bool _voteForClient,
        uint8 _clientAwardPercent
    ) external onlyRole(RESOLVER_ROLE) {
        require(_disputeId > 0 && _disputeId <= _disputeIdCounter.current(), "Invalid dispute ID");
        Dispute storage dispute = disputes[_disputeId];
        
        require(dispute.status == DisputeStatus.InProgress, "Dispute not in progress");
        require(dispute.resolutionMethod == ResolutionMethod.Manual, "Not manual resolution");
        require(!hasVoted[_disputeId][msg.sender], "Already voted");
        require(_clientAwardPercent <= 100, "Invalid percentage");
        
        // Record vote
        hasVoted[_disputeId][msg.sender] = true;
        if (_voteForClient) {
            votesForClient[_disputeId]++;
        } else {
            votesForFreelancer[_disputeId]++;
        }
        totalVotes[_disputeId]++;
        
        // Add to resolver's disputes
        resolverDisputes[msg.sender].push(_disputeId);
        
        emit ResolverVoted(_disputeId, msg.sender, _voteForClient);
        
        // Check if enough votes to reach a decision
        if (totalVotes[_disputeId] >= minVotesRequired) {
            uint256 clientVotes = votesForClient[_disputeId];
            uint256 freelancerVotes = votesForFreelancer[_disputeId];
            
            // Only resolve if there's a clear winner
            if (clientVotes != freelancerVotes) {
                bool clientWon = clientVotes > freelancerVotes;
                uint256 winnerPercent = clientWon ? _clientAwardPercent : (100 - _clientAwardPercent);
                uint256 loserPercent = 100 - winnerPercent;
                
                // Calculate awards based on vote percentages
                uint256 platformFee = dispute.amount * 5 / 100; // 5% platform fee
                uint256 remainingAmount = dispute.amount - platformFee;
                uint256 clientAward = clientWon 
                    ? remainingAmount * winnerPercent / 100
                    : remainingAmount * loserPercent / 100;
                uint256 freelancerAward = remainingAmount - clientAward;
                
                // Generate resolution string
                string memory resolution = clientWon
                    ? "Dispute resolved in favor of client"
                    : "Dispute resolved in favor of freelancer";
                
                // Process resolution
                _processResolution(
                    _disputeId,
                    ResolutionMethod.Manual,
                    msg.sender,
                    clientAward,
                    freelancerAward,
                    platformFee,
                    resolution
                );
            }
        }
    }
    
    /**
     * @dev Resolve a dispute through mediation
     * @param _disputeId ID of the dispute
     * @param _clientAward Amount awarded to client
     * @param _freelancerAward Amount awarded to freelancer
     * @param _platformFee Fee taken by platform
     * @param _resolution IPFS hash with resolution details
     */
    function resolveDisputeMediated(
        uint256 _disputeId,
        uint256 _clientAward,
        uint256 _freelancerAward,
        uint256 _platformFee,
        string calldata _resolution
    ) external onlyRole(RESOLVER_ROLE) nonReentrant {
        require(_disputeId > 0 && _disputeId <= _disputeIdCounter.current(), "Invalid dispute ID");
        Dispute storage dispute = disputes[_disputeId];
        
        require(dispute.status == DisputeStatus.InProgress, "Dispute not in progress");
        require(dispute.resolutionMethod == ResolutionMethod.Mediated, "Not mediated resolution");
        require(
            _clientAward + _freelancerAward + _platformFee <= dispute.amount,
            "Awards exceed dispute amount"
        );
        require(bytes(_resolution).length > 0, "Resolution required");
        
        // Process resolution
        _processResolution(
            _disputeId,
            ResolutionMethod.Mediated,
            msg.sender,
            _clientAward,
            _freelancerAward,
            _platformFee,
            _resolution
        );
    }
    
    /**
     * @dev Internal function to process a dispute resolution
     */
    function _processResolution(
        uint256 _disputeId,
        ResolutionMethod _method,
        address _resolver,
        uint256 _clientAward,
        uint256 _freelancerAward,
        uint256 _platformFee,
        string memory _resolution
    ) internal {
        Dispute storage dispute = disputes[_disputeId];
        
        // Update dispute
        dispute.status = DisputeStatus.Resolved;
        dispute.resolutionTime = block.timestamp;
        dispute.resolutionMethod = _method;
        dispute.resolver = _resolver;
        dispute.clientAward = _clientAward;
        dispute.freelancerAward = _freelancerAward;
        dispute.platformFee = _platformFee;
        dispute.resolution = _resolution;
        
        // Remove job dispute flag
        jobHasDispute[dispute.jobId] = false;
        
        // Handle escrow if any
        uint256 escrowAmount = disputeEscrows[_disputeId];
        if (escrowAmount > 0) {
            // Clear escrow
            disputeEscrows[_disputeId] = 0;
            
            // Distribute the escrow funds if any
            if (_clientAward > 0) {
                (bool clientSuccess, ) = dispute.client.call{value: _clientAward}("");
                require(clientSuccess, "Client payment failed");
                emit DisputeEscrowReleased(_disputeId, dispute.client, _clientAward);
            }
            
            if (_freelancerAward > 0) {
                (bool freelancerSuccess, ) = dispute.freelancer.call{value: _freelancerAward}("");
                require(freelancerSuccess, "Freelancer payment failed");
                emit DisputeEscrowReleased(_disputeId, dispute.freelancer, _freelancerAward);
            }
            
            if (_platformFee > 0) {
                // Send platform fee to admin
                (bool feeSuccess, ) = payable(getRoleMember(ADMIN_ROLE, 0)).call{value: _platformFee}("");
                require(feeSuccess, "Fee payment failed");
                emit DisputeEscrowReleased(_disputeId, getRoleMember(ADMIN_ROLE, 0), _platformFee);
            }
        }
        
        // Add to resolver's disputes if manual
        if (_method == ResolutionMethod.Manual || _method == ResolutionMethod.Mediated) {
            resolverDisputes[_resolver].push(_disputeId);
        }
        
        emit DisputeResolved(_disputeId, _method, _resolver, _clientAward, _freelancerAward);
    }
    
    /**
     * @dev Get dispute details
     * @param _disputeId Dispute ID
     * @return Dispute details
     */
    function getDispute(uint256 _disputeId) external view returns (Dispute memory) {
        require(_disputeId > 0 && _disputeId <= _disputeIdCounter.current(), "Invalid dispute ID");
        return disputes[_disputeId];
    }
    
    /**
     * @dev Get all disputes for a client
     * @param _client Client address
     * @return Array of dispute IDs
     */
    function getClientDisputes(address _client) external view returns (uint256[] memory) {
        return clientDisputes[_client];
    }
    
    /**
     * @dev Get all disputes for a freelancer
     * @param _freelancer Freelancer address
     * @return Array of dispute IDs
     */
    function getFreelancerDisputes(address _freelancer) external view returns (uint256[] memory) {
        return freelancerDisputes[_freelancer];
    }
    
    /**
     * @dev Get all disputes handled by a resolver
     * @param _resolver Resolver address
     * @return Array of dispute IDs
     */
    function getResolverDisputes(address _resolver) external view returns (uint256[] memory) {
        return resolverDisputes[_resolver];
    }
    
    /**
     * @dev Get vote counts for a dispute
     * @param _disputeId Dispute ID
     * @return clientVotes Number of votes for client
     * @return freelancerVotes Number of votes for freelancer
     * @return totalVoteCount Total number of votes
     */
    function getVoteCounts(uint256 _disputeId) external view returns (
        uint256 clientVotes,
        uint256 freelancerVotes,
        uint256 totalVoteCount
    ) {
        require(_disputeId > 0 && _disputeId <= _disputeIdCounter.current(), "Invalid dispute ID");
        
        return (
            votesForClient[_disputeId],
            votesForFreelancer[_disputeId],
            totalVotes[_disputeId]
        );
    }
    
    /**
     * @dev Check if a job has an active dispute
     * @param _jobId Job ID
     * @return True if job has an active dispute
     */
    function hasActiveDispute(uint256 _jobId) external view returns (bool) {
        return jobHasDispute[_jobId];
    }
} 