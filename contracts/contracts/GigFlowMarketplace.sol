// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title GigFlowMarketplace
 * @dev Main contract for the GigFlow decentralized gig economy marketplace
 * Handles job listings, proposals, escrow payments, and basic reputation
 */
contract GigFlowMarketplace is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;

    // Counters for job and proposal IDs
    Counters.Counter private _jobIdCounter;
    Counters.Counter private _proposalIdCounter;

    // Platform fee percentage (multiplied by 100 for precision, so 300 = 3%)
    uint256 public platformFeePercent = 300;
    
    // Address where platform fees are sent
    address public feeCollector;

    // Enum for job status
    enum JobStatus { 
        Open,       // Job is open for proposals
        InProgress, // Job has been assigned and is being worked on
        Completed,  // Job has been completed and payment released
        Cancelled   // Job has been cancelled
    }

    // Enum for proposal status
    enum ProposalStatus { 
        Pending,    // Proposal is awaiting client decision
        Accepted,   // Proposal has been accepted by client
        Rejected,   // Proposal has been rejected by client
        Withdrawn   // Proposal has been withdrawn by freelancer
    }

    // Struct for job listings
    struct Job {
        uint256 id;
        address client;
        string title;
        string description;
        string ipfsHash;       // IPFS hash containing detailed job information
        uint256 budget;        // Budget in wei
        uint256 deadline;      // Deadline timestamp
        JobStatus status;
        uint256 dateCreated;
        string[] requiredSkills;
        address assignedFreelancer;
        uint256 acceptedProposalId;
    }

    // Struct for proposals
    struct Proposal {
        uint256 id;
        uint256 jobId;
        address freelancer;
        string description;
        string ipfsHash;       // IPFS hash containing detailed proposal
        uint256 price;         // Proposed price in wei
        uint256 timeframe;     // Proposed timeframe in days
        ProposalStatus status;
        uint256 dateCreated;
    }

    // Struct for user profiles
    struct UserProfile {
        string name;
        string ipfsHash;       // IPFS hash containing profile details and portfolio
        bool isVerified;       // Whether the user has completed verification
        uint256 totalJobs;     // Total jobs completed (client or freelancer)
        uint256 reputationScore; // Reputation score (1-100)
    }

    // Struct for escrow
    struct Escrow {
        uint256 jobId;
        uint256 amount;
        bool released;
        bool refunded;
    }

    // Mappings
    mapping(uint256 => Job) public jobs;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => Proposal[]) public jobProposals;
    mapping(address => UserProfile) public userProfiles;
    mapping(uint256 => Escrow) public escrows;
    mapping(address => uint256[]) public clientJobs;
    mapping(address => uint256[]) public freelancerProposals;
    mapping(address => uint256[]) public freelancerJobs;

    // Events
    event JobCreated(uint256 indexed jobId, address indexed client, string title, uint256 budget);
    event JobUpdated(uint256 indexed jobId, string title, uint256 budget);
    event JobCancelled(uint256 indexed jobId);
    event ProposalSubmitted(uint256 indexed proposalId, uint256 indexed jobId, address indexed freelancer, uint256 price);
    event ProposalAccepted(uint256 indexed proposalId, uint256 indexed jobId, address indexed freelancer);
    event ProposalRejected(uint256 indexed proposalId, uint256 indexed jobId);
    event ProposalWithdrawn(uint256 indexed proposalId, uint256 indexed jobId, address indexed freelancer);
    event PaymentReleased(uint256 indexed jobId, address indexed freelancer, uint256 amount);
    event PaymentRefunded(uint256 indexed jobId, address indexed client, uint256 amount);
    event DisputeRaised(uint256 indexed jobId, address raiser, string reason);
    event DisputeResolved(uint256 indexed jobId, address resolver, bool freelancerFavor, uint256 freelancerAmount, uint256 clientAmount);
    event UserProfileUpdated(address indexed user, string name, string ipfsHash);
    event UserVerified(address indexed user);

    /**
     * @dev Constructor sets the fee collector address to the contract deployer
     */
    constructor() {
        feeCollector = msg.sender;
    }

    /**
     * @dev Set the platform fee percentage
     * @param _feePercent New fee percentage (multiplied by 100, so 300 = 3%)
     */
    function setPlatformFee(uint256 _feePercent) external onlyOwner {
        require(_feePercent <= 1000, "Fee too high"); // Max 10%
        platformFeePercent = _feePercent;
    }

    /**
     * @dev Set the fee collector address
     * @param _feeCollector Address where fees will be sent
     */
    function setFeeCollector(address _feeCollector) external onlyOwner {
        require(_feeCollector != address(0), "Invalid address");
        feeCollector = _feeCollector;
    }

    /**
     * @dev Create a new job listing
     * @param _title Job title
     * @param _description Brief job description
     * @param _ipfsHash IPFS hash containing full job details
     * @param _budget Budget in wei
     * @param _deadline Deadline timestamp
     * @param _requiredSkills Array of required skills
     */
    function createJob(
        string memory _title,
        string memory _description,
        string memory _ipfsHash,
        uint256 _budget,
        uint256 _deadline,
        string[] memory _requiredSkills
    ) external payable nonReentrant {
        require(msg.value >= _budget, "Insufficient funds");
        require(bytes(_title).length > 0, "Title required");
        require(bytes(_description).length > 0, "Description required");
        require(_deadline > block.timestamp, "Invalid deadline");

        _jobIdCounter.increment();
        uint256 newJobId = _jobIdCounter.current();

        jobs[newJobId] = Job({
            id: newJobId,
            client: msg.sender,
            title: _title,
            description: _description,
            ipfsHash: _ipfsHash,
            budget: _budget,
            deadline: _deadline,
            status: JobStatus.Open,
            dateCreated: block.timestamp,
            requiredSkills: _requiredSkills,
            assignedFreelancer: address(0),
            acceptedProposalId: 0
        });

        // Create an escrow for the job
        escrows[newJobId] = Escrow({
            jobId: newJobId,
            amount: msg.value,
            released: false,
            refunded: false
        });

        // Add to client's jobs
        clientJobs[msg.sender].push(newJobId);

        // Increment total jobs for client
        userProfiles[msg.sender].totalJobs += 1;

        emit JobCreated(newJobId, msg.sender, _title, _budget);
    }

    /**
     * @dev Submit a proposal for a job
     * @param _jobId The ID of the job
     * @param _description Brief proposal description
     * @param _ipfsHash IPFS hash containing full proposal details
     * @param _price Proposed price in wei
     * @param _timeframe Proposed timeframe in days
     */
    function submitProposal(
        uint256 _jobId,
        string memory _description,
        string memory _ipfsHash,
        uint256 _price,
        uint256 _timeframe
    ) external {
        require(_jobId <= _jobIdCounter.current(), "Job does not exist");
        require(jobs[_jobId].status == JobStatus.Open, "Job not open");
        require(jobs[_jobId].client != msg.sender, "Cannot propose to own job");
        require(bytes(_description).length > 0, "Description required");
        require(_price > 0, "Price must be greater than 0");
        require(_timeframe > 0, "Timeframe must be greater than 0");

        _proposalIdCounter.increment();
        uint256 newProposalId = _proposalIdCounter.current();

        Proposal memory newProposal = Proposal({
            id: newProposalId,
            jobId: _jobId,
            freelancer: msg.sender,
            description: _description,
            ipfsHash: _ipfsHash,
            price: _price,
            timeframe: _timeframe,
            status: ProposalStatus.Pending,
            dateCreated: block.timestamp
        });

        proposals[newProposalId] = newProposal;
        jobProposals[_jobId].push(newProposal);
        freelancerProposals[msg.sender].push(newProposalId);

        emit ProposalSubmitted(newProposalId, _jobId, msg.sender, _price);
    }

    /**
     * @dev Accept a proposal and start the job
     * @param _proposalId The ID of the proposal to accept
     */
    function acceptProposal(uint256 _proposalId) external {
        require(_proposalId <= _proposalIdCounter.current(), "Proposal does not exist");
        
        Proposal storage proposal = proposals[_proposalId];
        uint256 jobId = proposal.jobId;
        
        require(jobs[jobId].client == msg.sender, "Not job owner");
        require(jobs[jobId].status == JobStatus.Open, "Job not open");
        require(proposal.status == ProposalStatus.Pending, "Proposal not pending");
        require(escrows[jobId].amount >= proposal.price, "Insufficient escrow");

        // Update job status
        jobs[jobId].status = JobStatus.InProgress;
        jobs[jobId].assignedFreelancer = proposal.freelancer;
        jobs[jobId].acceptedProposalId = _proposalId;

        // Update proposal status
        proposal.status = ProposalStatus.Accepted;

        // Add to freelancer's active jobs
        freelancerJobs[proposal.freelancer].push(jobId);

        // Increment total jobs for freelancer
        userProfiles[proposal.freelancer].totalJobs += 1;

        // Reject all other proposals
        for (uint256 i = 0; i < jobProposals[jobId].length; i++) {
            uint256 propId = jobProposals[jobId][i].id;
            if (propId != _proposalId && proposals[propId].status == ProposalStatus.Pending) {
                proposals[propId].status = ProposalStatus.Rejected;
                emit ProposalRejected(propId, jobId);
            }
        }

        emit ProposalAccepted(_proposalId, jobId, proposal.freelancer);
    }

    /**
     * @dev Complete a job and release payment
     * @param _jobId The ID of the job to complete
     */
    function completeJob(uint256 _jobId) external nonReentrant {
        require(_jobId <= _jobIdCounter.current(), "Job does not exist");
        
        Job storage job = jobs[_jobId];
        Escrow storage escrow = escrows[_jobId];
        Proposal storage acceptedProposal = proposals[job.acceptedProposalId];
        
        require(job.client == msg.sender, "Not job owner");
        require(job.status == JobStatus.InProgress, "Job not in progress");
        require(!escrow.released && !escrow.refunded, "Payment already processed");

        job.status = JobStatus.Completed;
        escrow.released = true;

        // Calculate platform fee
        uint256 fee = (acceptedProposal.price * platformFeePercent) / 10000;
        uint256 freelancerPayment = acceptedProposal.price - fee;

        // Return remaining escrow to client if there is any
        uint256 remainingFunds = escrow.amount - acceptedProposal.price;
        
        // Send payments
        if (fee > 0) {
            (bool feeSuccess, ) = feeCollector.call{value: fee}("");
            require(feeSuccess, "Fee transfer failed");
        }
        
        (bool freelancerSuccess, ) = job.assignedFreelancer.call{value: freelancerPayment}("");
        require(freelancerSuccess, "Freelancer payment failed");
        
        if (remainingFunds > 0) {
            (bool clientSuccess, ) = job.client.call{value: remainingFunds}("");
            require(clientSuccess, "Client refund failed");
        }

        emit PaymentReleased(_jobId, job.assignedFreelancer, freelancerPayment);
    }

    /**
     * @dev Cancel a job if no proposal has been accepted
     * @param _jobId The ID of the job to cancel
     */
    function cancelJob(uint256 _jobId) external nonReentrant {
        require(_jobId <= _jobIdCounter.current(), "Job does not exist");
        
        Job storage job = jobs[_jobId];
        Escrow storage escrow = escrows[_jobId];
        
        require(job.client == msg.sender, "Not job owner");
        require(job.status == JobStatus.Open, "Job not open");
        require(!escrow.released && !escrow.refunded, "Payment already processed");

        job.status = JobStatus.Cancelled;
        escrow.refunded = true;

        // Refund the client
        (bool success, ) = job.client.call{value: escrow.amount}("");
        require(success, "Refund failed");

        emit JobCancelled(_jobId);
        emit PaymentRefunded(_jobId, job.client, escrow.amount);
    }

    /**
     * @dev Withdraw a proposal if it hasn't been accepted
     * @param _proposalId The ID of the proposal to withdraw
     */
    function withdrawProposal(uint256 _proposalId) external {
        require(_proposalId <= _proposalIdCounter.current(), "Proposal does not exist");
        
        Proposal storage proposal = proposals[_proposalId];
        
        require(proposal.freelancer == msg.sender, "Not proposal owner");
        require(proposal.status == ProposalStatus.Pending, "Proposal not pending");

        proposal.status = ProposalStatus.Withdrawn;

        emit ProposalWithdrawn(_proposalId, proposal.jobId, msg.sender);
    }

    /**
     * @dev Update user profile
     * @param _name User's display name
     * @param _ipfsHash IPFS hash containing profile details
     */
    function updateProfile(string memory _name, string memory _ipfsHash) external {
        require(bytes(_name).length > 0, "Name required");
        require(bytes(_ipfsHash).length > 0, "IPFS hash required");

        UserProfile storage profile = userProfiles[msg.sender];
        profile.name = _name;
        profile.ipfsHash = _ipfsHash;

        emit UserProfileUpdated(msg.sender, _name, _ipfsHash);
    }

    /**
     * @dev Update reputation score (only callable by AI oracle or owner)
     * @param _user User address
     * @param _score New reputation score (1-100)
     */
    function updateReputationScore(address _user, uint256 _score) external onlyOwner {
        require(_user != address(0), "Invalid address");
        require(_score >= 1 && _score <= 100, "Score out of range");

        userProfiles[_user].reputationScore = _score;
    }

    /**
     * @dev Verify a user (only callable by owner)
     * @param _user User address to verify
     */
    function verifyUser(address _user) external onlyOwner {
        require(_user != address(0), "Invalid address");
        
        userProfiles[_user].isVerified = true;
        
        emit UserVerified(_user);
    }

    /**
     * @dev Get all jobs created by a client
     * @param _client Client address
     * @return Array of job IDs
     */
    function getClientJobs(address _client) external view returns (uint256[] memory) {
        return clientJobs[_client];
    }

    /**
     * @dev Get all proposals submitted by a freelancer
     * @param _freelancer Freelancer address
     * @return Array of proposal IDs
     */
    function getFreelancerProposals(address _freelancer) external view returns (uint256[] memory) {
        return freelancerProposals[_freelancer];
    }

    /**
     * @dev Get all jobs assigned to a freelancer
     * @param _freelancer Freelancer address
     * @return Array of job IDs
     */
    function getFreelancerJobs(address _freelancer) external view returns (uint256[] memory) {
        return freelancerJobs[_freelancer];
    }

    /**
     * @dev Get all proposals for a job
     * @param _jobId Job ID
     * @return Array of proposals
     */
    function getJobProposals(uint256 _jobId) external view returns (Proposal[] memory) {
        return jobProposals[_jobId];
    }

    /**
     * @dev Get job details
     * @param _jobId Job ID
     * @return Job details
     */
    function getJob(uint256 _jobId) external view returns (Job memory) {
        require(_jobId <= _jobIdCounter.current(), "Job does not exist");
        return jobs[_jobId];
    }

    /**
     * @dev Get proposal details
     * @param _proposalId Proposal ID
     * @return Proposal details
     */
    function getProposal(uint256 _proposalId) external view returns (Proposal memory) {
        require(_proposalId <= _proposalIdCounter.current(), "Proposal does not exist");
        return proposals[_proposalId];
    }

    /**
     * @dev Get user profile
     * @param _user User address
     * @return User profile details
     */
    function getUserProfile(address _user) external view returns (UserProfile memory) {
        return userProfiles[_user];
    }
} 