// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title GigFlowToken
 * @dev ERC20 token for the GigFlow platform with governance, staking, and incentives
 */
contract GigFlowToken is ERC20, ERC20Burnable, Pausable, AccessControl {
    using SafeMath for uint256;
    
    // Roles
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    
    // Token distribution
    uint256 public constant MAX_SUPPLY = 100000000 * 10**18; // 100 million tokens
    uint256 public constant INITIAL_SUPPLY = 20000000 * 10**18; // 20 million tokens
    
    // Token distribution percentages (in basis points, e.g., 1000 = 10%)
    uint256 public constant TEAM_ALLOCATION = 1500; // 15%
    uint256 public constant ECOSYSTEM_FUND = 2500; // 25%
    uint256 public constant COMMUNITY_REWARDS = 3500; // 35%
    uint256 public constant PRIVATE_SALE = 1000; // 10%
    uint256 public constant PUBLIC_SALE = 1000; // 10%
    uint256 public constant LIQUIDITY_POOL = 500; // 5%
    
    // Vesting periods in seconds
    uint256 public constant TEAM_VESTING_PERIOD = 365 days * 2; // 2 years
    uint256 public constant ECOSYSTEM_VESTING_PERIOD = 365 days * 3; // 3 years
    
    // Release schedule for team tokens (cliff at 6 months, then monthly release)
    uint256 public constant TEAM_CLIFF = 180 days;
    uint256 public constant TEAM_RELEASE_INTERVAL = 30 days;
    uint256 public constant TEAM_RELEASE_PERIODS = 18; // 18 months after cliff
    
    // Staking rewards
    uint256 public rewardRate = 500; // 5% annual return (in basis points)
    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public stakingTimestamp;
    mapping(address => uint256) public lastRewardsClaim;
    
    // Addresses
    address public teamWallet;
    address public ecosystemWallet;
    address public communityWallet;
    address public privateSaleWallet;
    address public publicSaleWallet;
    address public liquidityWallet;
    
    // Vesting tracking
    uint256 public teamVestingStart;
    uint256 public ecosystemVestingStart;
    uint256 public teamTokensReleased;
    uint256 public ecosystemTokensReleased;
    
    // Events
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event TeamTokensReleased(uint256 amount);
    event EcosystemTokensReleased(uint256 amount);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);

    /**
     * @dev Constructor sets up the initial token distribution and roles
     * @param _admin Admin address for role management
     * @param _teamWallet Address for team token allocation
     * @param _ecosystemWallet Address for ecosystem fund
     * @param _communityWallet Address for community rewards
     * @param _privateSaleWallet Address for private sale
     * @param _publicSaleWallet Address for public sale
     * @param _liquidityWallet Address for liquidity pool
     */
    constructor(
        address _admin,
        address _teamWallet,
        address _ecosystemWallet,
        address _communityWallet,
        address _privateSaleWallet,
        address _publicSaleWallet,
        address _liquidityWallet
    ) ERC20("GigFlow Token", "GFT") {
        require(_admin != address(0), "Invalid admin address");
        require(_teamWallet != address(0), "Invalid team wallet");
        require(_ecosystemWallet != address(0), "Invalid ecosystem wallet");
        require(_communityWallet != address(0), "Invalid community wallet");
        require(_privateSaleWallet != address(0), "Invalid private sale wallet");
        require(_publicSaleWallet != address(0), "Invalid public sale wallet");
        require(_liquidityWallet != address(0), "Invalid liquidity wallet");
        
        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin);
        _grantRole(MINTER_ROLE, _admin);
        _grantRole(GOVERNANCE_ROLE, _admin);
        
        // Set up wallet addresses
        teamWallet = _teamWallet;
        ecosystemWallet = _ecosystemWallet;
        communityWallet = _communityWallet;
        privateSaleWallet = _privateSaleWallet;
        publicSaleWallet = _publicSaleWallet;
        liquidityWallet = _liquidityWallet;
        
        // Set up vesting start times
        teamVestingStart = block.timestamp;
        ecosystemVestingStart = block.timestamp;
        
        // Initial token distribution
        _mint(address(this), INITIAL_SUPPLY); // Mint initial supply to contract
        
        // Distribute tokens according to allocation
        uint256 teamAmount = INITIAL_SUPPLY.mul(TEAM_ALLOCATION).div(10000); // Vested
        uint256 ecosystemAmount = INITIAL_SUPPLY.mul(ECOSYSTEM_FUND).div(10000); // Vested
        uint256 communityAmount = INITIAL_SUPPLY.mul(COMMUNITY_REWARDS).div(10000);
        uint256 privateSaleAmount = INITIAL_SUPPLY.mul(PRIVATE_SALE).div(10000);
        uint256 publicSaleAmount = INITIAL_SUPPLY.mul(PUBLIC_SALE).div(10000);
        uint256 liquidityAmount = INITIAL_SUPPLY.mul(LIQUIDITY_POOL).div(10000);
        
        // Transfer immediate allocations
        _transfer(address(this), communityWallet, communityAmount);
        _transfer(address(this), privateSaleWallet, privateSaleAmount);
        _transfer(address(this), publicSaleWallet, publicSaleAmount);
        _transfer(address(this), liquidityWallet, liquidityAmount);
        
        // Note: Team and ecosystem tokens are held by the contract for vesting
    }
    
    /**
     * @dev Pause token transfers
     */
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause token transfers
     */
    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev Mint new tokens (up to MAX_SUPPLY)
     * @param to Recipient address
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");
        _mint(to, amount);
    }
    
    /**
     * @dev Update reward rate for staking
     * @param _newRate New reward rate (in basis points)
     */
    function updateRewardRate(uint256 _newRate) external onlyRole(GOVERNANCE_ROLE) {
        require(_newRate <= 2000, "Rate too high"); // Max 20%
        uint256 oldRate = rewardRate;
        rewardRate = _newRate;
        emit RewardRateUpdated(oldRate, _newRate);
    }
    
    /**
     * @dev Stake tokens
     * @param _amount Amount to stake
     */
    function stake(uint256 _amount) external whenNotPaused {
        require(_amount > 0, "Cannot stake 0");
        require(balanceOf(msg.sender) >= _amount, "Insufficient balance");
        
        // Claim any pending rewards first
        _claimRewards(msg.sender);
        
        // Update staking info
        stakedBalance[msg.sender] = stakedBalance[msg.sender].add(_amount);
        stakingTimestamp[msg.sender] = block.timestamp;
        lastRewardsClaim[msg.sender] = block.timestamp;
        
        // Transfer tokens to contract
        _transfer(msg.sender, address(this), _amount);
        
        emit Staked(msg.sender, _amount);
    }
    
    /**
     * @dev Unstake tokens
     * @param _amount Amount to unstake
     */
    function unstake(uint256 _amount) external {
        require(stakedBalance[msg.sender] >= _amount, "Insufficient staked balance");
        
        // Claim any pending rewards first
        _claimRewards(msg.sender);
        
        // Update staking info
        stakedBalance[msg.sender] = stakedBalance[msg.sender].sub(_amount);
        
        // Transfer tokens back to user
        _transfer(address(this), msg.sender, _amount);
        
        emit Unstaked(msg.sender, _amount);
    }
    
    /**
     * @dev Claim staking rewards
     */
    function claimRewards() external {
        _claimRewards(msg.sender);
    }
    
    /**
     * @dev Internal function to calculate and distribute staking rewards
     * @param _user User address
     */
    function _claimRewards(address _user) internal {
        uint256 reward = calculatePendingRewards(_user);
        
        if (reward > 0) {
            // Update last claim timestamp
            lastRewardsClaim[_user] = block.timestamp;
            
            // Mint rewards to user
            if (totalSupply().add(reward) <= MAX_SUPPLY) {
                _mint(_user, reward);
                emit RewardPaid(_user, reward);
            }
        }
    }
    
    /**
     * @dev Calculate pending staking rewards
     * @param _user User address
     * @return Pending reward amount
     */
    function calculatePendingRewards(address _user) public view returns (uint256) {
        if (stakedBalance[_user] == 0 || lastRewardsClaim[_user] == 0) {
            return 0;
        }
        
        uint256 timeStaked = block.timestamp.sub(lastRewardsClaim[_user]);
        uint256 annualReward = stakedBalance[_user].mul(rewardRate).div(10000);
        uint256 reward = annualReward.mul(timeStaked).div(365 days);
        
        return reward;
    }
    
    /**
     * @dev Release vested team tokens
     */
    function releaseTeamTokens() external {
        require(block.timestamp >= teamVestingStart.add(TEAM_CLIFF), "Cliff not reached");
        
        uint256 teamTokenTotal = INITIAL_SUPPLY.mul(TEAM_ALLOCATION).div(10000);
        uint256 vestedAmount;
        
        if (block.timestamp >= teamVestingStart.add(TEAM_CLIFF).add(TEAM_RELEASE_INTERVAL.mul(TEAM_RELEASE_PERIODS))) {
            // After vesting period, all tokens are released
            vestedAmount = teamTokenTotal;
        } else {
            // During vesting period, calculate releasable amount
            uint256 timeFromCliff = block.timestamp.sub(teamVestingStart.add(TEAM_CLIFF));
            uint256 releasePeriods = timeFromCliff.div(TEAM_RELEASE_INTERVAL);
            
            vestedAmount = teamTokenTotal.mul(releasePeriods).div(TEAM_RELEASE_PERIODS);
        }
        
        uint256 releasableAmount = vestedAmount.sub(teamTokensReleased);
        require(releasableAmount > 0, "No tokens to release");
        
        teamTokensReleased = teamTokensReleased.add(releasableAmount);
        _transfer(address(this), teamWallet, releasableAmount);
        
        emit TeamTokensReleased(releasableAmount);
    }
    
    /**
     * @dev Release vested ecosystem tokens
     */
    function releaseEcosystemTokens() external {
        uint256 ecosystemTokenTotal = INITIAL_SUPPLY.mul(ECOSYSTEM_FUND).div(10000);
        uint256 timeElapsed = block.timestamp.sub(ecosystemVestingStart);
        
        uint256 vestedAmount;
        if (timeElapsed >= ECOSYSTEM_VESTING_PERIOD) {
            // After vesting period, all tokens are released
            vestedAmount = ecosystemTokenTotal;
        } else {
            // During vesting period, linear release
            vestedAmount = ecosystemTokenTotal.mul(timeElapsed).div(ECOSYSTEM_VESTING_PERIOD);
        }
        
        uint256 releasableAmount = vestedAmount.sub(ecosystemTokensReleased);
        require(releasableAmount > 0, "No tokens to release");
        
        ecosystemTokensReleased = ecosystemTokensReleased.add(releasableAmount);
        _transfer(address(this), ecosystemWallet, releasableAmount);
        
        emit EcosystemTokensReleased(releasableAmount);
    }
    
    /**
     * @dev See remaining team allocation
     * @return Remaining team tokens
     */
    function getUnreleasedTeamTokens() external view returns (uint256) {
        uint256 teamTokenTotal = INITIAL_SUPPLY.mul(TEAM_ALLOCATION).div(10000);
        return teamTokenTotal.sub(teamTokensReleased);
    }
    
    /**
     * @dev See remaining ecosystem allocation
     * @return Remaining ecosystem tokens
     */
    function getUnreleasedEcosystemTokens() external view returns (uint256) {
        uint256 ecosystemTokenTotal = INITIAL_SUPPLY.mul(ECOSYSTEM_FUND).div(10000);
        return ecosystemTokenTotal.sub(ecosystemTokensReleased);
    }
    
    /**
     * @dev See total staked tokens
     * @param _user User address
     * @return Staked amount and pending rewards
     */
    function getStakingInfo(address _user) external view returns (uint256 staked, uint256 pendingRewards) {
        return (stakedBalance[_user], calculatePendingRewards(_user));
    }
    
    /**
     * @dev Override _beforeTokenTransfer hook
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }
} 