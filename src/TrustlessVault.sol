// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./ValidationRegistry.sol";

/**
 * @title TrustlessVault
 * @dev A staking vault that only allows validated agents to harvest rewards
 * @notice This contract implements ERC-8004 principles for trustless yield farming
 */
contract TrustlessVault is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // The staking token
    IERC20 public immutable stakingToken;

    // The validation registry to check agent permissions
    ValidationRegistry public validationRegistry;

    // Total amount staked in the vault
    uint256 public totalStaked;

    // Mapping from user address to staked amount
    mapping(address => uint256) public stakedAmount;

    // Mapping from user address to last harvest timestamp
    mapping(address => uint256) public lastHarvestTime;

    // Reward tracking variables
    uint256 public accRewardPerShare; // Accumulated rewards per share (scaled by 1e18)
    uint256 public lastRewardTime; // Last time rewards were calculated
    uint256 public rewardPerSecond; // Reward rate per second
    uint256 public constant PRECISION = 1e18; // Precision for calculations

    // Mapping from user address to pending rewards
    mapping(address => uint256) public pendingRewards;

    // Mapping from user address to reward debt (for tracking)
    mapping(address => uint256) public rewardDebt;

    // Events
    event Staked(address indexed user, uint256 amount, uint256 timestamp);
    event Unstaked(address indexed user, uint256 amount, uint256 timestamp);
    event Harvested(address indexed agent, address indexed user, uint256 reward, uint256 timestamp);
    event ValidationRegistryUpdated(address indexed oldRegistry, address indexed newRegistry);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate, uint256 timestamp);
    event RewardsDeposited(uint256 amount, uint256 timestamp);

    // Modifiers
    modifier onlyValidatedAgent() {
        require(
            validationRegistry.isAgentValidated(msg.sender, address(this)),
            "TrustlessVault: Only validated agents can harvest"
        );
        _;
    }

    /**
     * @dev Constructor
     * @param _stakingToken The address of the staking token
     * @param _validationRegistry The address of the validation registry
     * @param _rewardPerSecond Initial reward rate per second
     */
    constructor(address _stakingToken, address _validationRegistry, uint256 _rewardPerSecond) Ownable(msg.sender) {
        require(_stakingToken != address(0), "TrustlessVault: Invalid staking token address");
        require(_validationRegistry != address(0), "TrustlessVault: Invalid validation registry address");

        stakingToken = IERC20(_stakingToken);
        validationRegistry = ValidationRegistry(_validationRegistry);
        rewardPerSecond = _rewardPerSecond;
        lastRewardTime = block.timestamp;
    }

    /**
     * @dev Update reward variables of the given pool
     */
    function updateRewards() public {
        if (block.timestamp <= lastRewardTime) {
            return;
        }

        if (totalStaked == 0) {
            lastRewardTime = block.timestamp;
            return;
        }

        uint256 timeElapsed = block.timestamp - lastRewardTime;
        uint256 reward = timeElapsed * rewardPerSecond;

        accRewardPerShare += (reward * PRECISION) / totalStaked;
        lastRewardTime = block.timestamp;
    }

    /**
     * @dev Stake tokens in the vault
     * @param amount The amount of tokens to stake
     */
    function stake(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "TrustlessVault: Amount must be greater than zero");
        require(stakingToken.balanceOf(msg.sender) >= amount, "TrustlessVault: Insufficient token balance");

        // Update rewards before staking
        updateRewards();

        // Transfer tokens from user to vault
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        // Update staking records
        stakedAmount[msg.sender] += amount;
        totalStaked += amount;

        // Update reward debt for the user
        rewardDebt[msg.sender] += (amount * accRewardPerShare) / PRECISION;

        // Set initial harvest time
        if (lastHarvestTime[msg.sender] == 0) {
            lastHarvestTime[msg.sender] = block.timestamp;
        }

        emit Staked(msg.sender, amount, block.timestamp);
    }

    /**
     * @dev Harvest rewards for a user (only callable by validated agents)
     * @param user The address of the user to harvest rewards for
     */
    function harvest(address user) external onlyValidatedAgent nonReentrant whenNotPaused {
        require(user != address(0), "TrustlessVault: Invalid user address");
        require(stakedAmount[user] > 0, "TrustlessVault: No staked amount for user");

        // Update rewards before harvesting
        updateRewards();

        uint256 pending = _computeReward(user);
        require(pending > 0, "TrustlessVault: No rewards to harvest");
        require(stakingToken.balanceOf(address(this)) >= pending, "TrustlessVault: Insufficient reward balance");

        // Update reward debt
        rewardDebt[user] += pending;

        // Update last harvest time
        lastHarvestTime[user] = block.timestamp;

        // Transfer reward to user
        stakingToken.safeTransfer(user, pending);

        emit Harvested(msg.sender, user, pending, block.timestamp);
    }

    /**
     * @dev Compute the pending reward for a user
     * @param user The address of the user
     * @return The pending reward amount
     */
    function _computeReward(address user) internal view returns (uint256) {
        if (stakedAmount[user] == 0) {
            return 0;
        }

        uint256 currentAccRewardPerShare = accRewardPerShare;

        if (block.timestamp > lastRewardTime && totalStaked > 0) {
            uint256 timeElapsed = block.timestamp - lastRewardTime;
            uint256 reward = timeElapsed * rewardPerSecond;
            currentAccRewardPerShare += (reward * PRECISION) / totalStaked;
        }

        uint256 userReward = (stakedAmount[user] * currentAccRewardPerShare) / PRECISION;
        return userReward - rewardDebt[user];
    }

    /**
     * @dev Get the pending reward for a user
     * @param user The address of the user
     * @return The pending reward amount
     */
    function getPendingReward(address user) external view returns (uint256) {
        return _computeReward(user);
    }

    /**
     * @dev Unstake tokens from the vault
     * @param amount The amount of tokens to unstake
     */
    function unstake(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "TrustlessVault: Amount must be greater than zero");
        require(stakedAmount[msg.sender] >= amount, "TrustlessVault: Insufficient staked amount");

        // Update rewards before unstaking
        updateRewards();

        // Update staking records
        stakedAmount[msg.sender] -= amount;
        totalStaked -= amount;

        // Update reward debt
        rewardDebt[msg.sender] -= (amount * accRewardPerShare) / PRECISION;

        // Transfer tokens back to user
        stakingToken.safeTransfer(msg.sender, amount);

        emit Unstaked(msg.sender, amount, block.timestamp);
    }

    /**
     * @dev Deposit rewards into the vault (only owner)
     * @param amount The amount of reward tokens to deposit
     */
    function depositRewards(uint256 amount) external onlyOwner {
        require(amount > 0, "TrustlessVault: Amount must be greater than zero");
        require(stakingToken.balanceOf(msg.sender) >= amount, "TrustlessVault: Insufficient balance");

        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit RewardsDeposited(amount, block.timestamp);
    }

    /**
     * @dev Set the reward rate per second (only owner)
     * @param _rewardPerSecond The new reward rate per second
     */
    function setRewardRate(uint256 _rewardPerSecond) external onlyOwner {
        updateRewards();

        uint256 oldRate = rewardPerSecond;
        rewardPerSecond = _rewardPerSecond;

        emit RewardRateUpdated(oldRate, _rewardPerSecond, block.timestamp);
    }

    /**
     * @dev Set the validation registry (only owner)
     * @param newRegistry The address of the new validation registry
     */
    function setValidationRegistry(address newRegistry) external onlyOwner {
        require(newRegistry != address(0), "TrustlessVault: Invalid registry address");
        require(newRegistry != address(validationRegistry), "TrustlessVault: Registry must be different");

        address oldRegistry = address(validationRegistry);
        validationRegistry = ValidationRegistry(newRegistry);

        emit ValidationRegistryUpdated(oldRegistry, newRegistry);
    }

    /**
     * @dev Pause the contract (only owner)
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause the contract (only owner)
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Get the total balance of staking tokens in the vault
     * @return The total balance of staking tokens
     */
    function getVaultBalance() external view returns (uint256) {
        return stakingToken.balanceOf(address(this));
    }

    /**
     * @dev Get staking information for a user
     * @param user The address of the user
     * @return staked The amount staked by the user
     * @return pendingReward The pending reward for the user
     * @return lastHarvest The timestamp of the last harvest
     */
    function getUserInfo(address user)
        external
        view
        returns (uint256 staked, uint256 pendingReward, uint256 lastHarvest)
    {
        staked = stakedAmount[user];
        pendingReward = _computeReward(user);
        lastHarvest = lastHarvestTime[user];
    }

    /**
     * @dev Get vault statistics
     * @return totalStakedAmount Total amount staked
     * @return currentRewardRate Current reward rate per second
     * @return accRewardPerShareAccumulated Accumulated rewards per share
     * @return lastRewardUpdate Last time rewards were updated
     */
    function getVaultStats()
        external
        view
        returns (
            uint256 totalStakedAmount,
            uint256 currentRewardRate,
            uint256 accRewardPerShareAccumulated,
            uint256 lastRewardUpdate
        )
    {
        totalStakedAmount = totalStaked;
        currentRewardRate = rewardPerSecond;
        accRewardPerShareAccumulated = accRewardPerShare;
        lastRewardUpdate = lastRewardTime;
    }
}
