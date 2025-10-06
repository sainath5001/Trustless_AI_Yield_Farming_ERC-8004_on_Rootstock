// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ValidationRegistry.sol";

/**
 * @title TrustlessVault
 * @dev A staking vault that only allows validated agents to harvest rewards
 * @notice This contract implements ERC-8004 principles for trustless yield farming
 */
contract TrustlessVault is Ownable {
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

    // Reward rate: 0.1% per harvest (1000 = 0.1%)
    uint256 public constant REWARD_RATE = 1000; // 0.1%
    uint256 public constant RATE_DENOMINATOR = 1000000; // For precision

    // Events
    event Staked(address indexed user, uint256 amount, uint256 timestamp);
    event Harvested(address indexed agent, address indexed user, uint256 reward, uint256 timestamp);
    event ValidationRegistryUpdated(address indexed oldRegistry, address indexed newRegistry);

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
     */
    constructor(address _stakingToken, address _validationRegistry) Ownable(msg.sender) {
        require(_stakingToken != address(0), "TrustlessVault: Invalid staking token address");
        require(_validationRegistry != address(0), "TrustlessVault: Invalid validation registry address");

        stakingToken = IERC20(_stakingToken);
        validationRegistry = ValidationRegistry(_validationRegistry);
    }

    /**
     * @dev Stake tokens in the vault
     * @param amount The amount of tokens to stake
     */
    function stake(uint256 amount) external {
        require(amount > 0, "TrustlessVault: Amount must be greater than zero");
        require(stakingToken.balanceOf(msg.sender) >= amount, "TrustlessVault: Insufficient token balance");

        // Transfer tokens from user to vault
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        // Update staking records
        stakedAmount[msg.sender] += amount;
        totalStaked += amount;

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
    function harvest(address user) external onlyValidatedAgent {
        require(user != address(0), "TrustlessVault: Invalid user address");
        require(stakedAmount[user] > 0, "TrustlessVault: No staked amount for user");

        uint256 reward = _computeReward(user);
        require(reward > 0, "TrustlessVault: No rewards to harvest");

        // Update last harvest time
        lastHarvestTime[user] = block.timestamp;

        // Transfer reward to user
        stakingToken.safeTransfer(user, reward);

        emit Harvested(msg.sender, user, reward, block.timestamp);
    }

    /**
     * @dev Compute the reward for a user based on their staked amount
     * @param user The address of the user
     * @return The reward amount (0.1% of total staked)
     */
    function _computeReward(address user) internal view returns (uint256) {
        if (stakedAmount[user] == 0 || totalStaked == 0) {
            return 0;
        }

        // Calculate 0.1% of total staked as reward
        uint256 baseReward = (totalStaked * REWARD_RATE) / RATE_DENOMINATOR;

        // Scale reward based on user's stake proportion
        uint256 userReward = (baseReward * stakedAmount[user]) / totalStaked;

        return userReward;
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
    function unstake(uint256 amount) external {
        require(amount > 0, "TrustlessVault: Amount must be greater than zero");
        require(stakedAmount[msg.sender] >= amount, "TrustlessVault: Insufficient staked amount");

        // Update staking records
        stakedAmount[msg.sender] -= amount;
        totalStaked -= amount;

        // Transfer tokens back to user
        stakingToken.safeTransfer(msg.sender, amount);
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
}
