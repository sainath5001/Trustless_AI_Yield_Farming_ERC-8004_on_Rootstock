// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/IdentityRegistry.sol";
import "../src/ReputationRegistry.sol";
import "../src/ValidationRegistry.sol";
import "../src/MockToken.sol";
import "../src/TrustlessVault.sol";
import "../src/Agent.sol";

/**
 * @title VaultTest
 * @dev Comprehensive test suite for the Trustless Yield Farming Bot system
 * @notice Tests verify staking, validation, and harvest functionality
 */
contract VaultTest is Test {
    // Contract instances
    IdentityRegistry public identityRegistry;
    ReputationRegistry public reputationRegistry;
    ValidationRegistry public validationRegistry;
    MockToken public mockToken;
    TrustlessVault public trustlessVault;
    JobCommitmentRegistry public jobCommitmentRegistry;
    Agent public agent;

    // Test addresses
    address public deployer;
    address public user1;
    address public user2;
    address public nonValidatedAgent;

    // Test constants
    uint256 public constant INITIAL_SUPPLY = 1000000 * 10 ** 18;
    uint256 public constant STAKE_AMOUNT = 1000 * 10 ** 18;

    function setUp() public {
        // Set up test addresses
        deployer = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        nonValidatedAgent = makeAddr("nonValidatedAgent");

        // Deploy contracts
        identityRegistry = new IdentityRegistry();
        reputationRegistry = new ReputationRegistry();
        mockToken = new MockToken();
        validationRegistry = new ValidationRegistry(deployer, address(mockToken), 1000 * 10 ** 18, 30 days);
        trustlessVault = new TrustlessVault(address(mockToken), address(validationRegistry), 1 * 10 ** 18);
        jobCommitmentRegistry = new JobCommitmentRegistry();
        agent = new Agent(address(identityRegistry), address(jobCommitmentRegistry));

        // Register agent
        string memory metadataUri = "https://example.com/agent-metadata.json";
        agent.register(metadataUri);

        // Set agent validation
        mockToken.approve(address(validationRegistry), 1000 * 10 ** 18);
        validationRegistry.setValidation(
            address(agent), address(trustlessVault), true, 1000 * 10 ** 18, "Test validation"
        );

        // Set agent reputation
        reputationRegistry.setReputation(address(agent), 1000, "Test reputation");

        // Distribute tokens to test users
        mockToken.transfer(user1, STAKE_AMOUNT * 2);
        mockToken.transfer(user2, STAKE_AMOUNT * 2);

        // Deposit rewards into the vault
        mockToken.approve(address(trustlessVault), 100000 * 10 ** 18);
        trustlessVault.depositRewards(100000 * 10 ** 18);
    }

    function testUserCanStakeTokens() public {
        // Arrange
        uint256 stakeAmount = STAKE_AMOUNT;
        vm.startPrank(user1);
        mockToken.approve(address(trustlessVault), stakeAmount);

        // Act
        trustlessVault.stake(stakeAmount);

        // Assert
        assertEq(trustlessVault.stakedAmount(user1), stakeAmount);
        assertEq(trustlessVault.totalStaked(), stakeAmount);
        assertEq(mockToken.balanceOf(user1), STAKE_AMOUNT); // Should have 1000 left
        assertEq(mockToken.balanceOf(address(trustlessVault)), stakeAmount);
    }

    function testNonValidatedAgentCannotHarvest() public {
        // Arrange
        uint256 stakeAmount = STAKE_AMOUNT;
        vm.startPrank(user1);
        mockToken.approve(address(trustlessVault), stakeAmount);
        trustlessVault.stake(stakeAmount);
        vm.stopPrank();

        // Act & Assert
        vm.startPrank(nonValidatedAgent);
        vm.expectRevert("TrustlessVault: Only validated agents can harvest");
        trustlessVault.harvest(user1);
        vm.stopPrank();
    }

    function testValidatedAgentCanHarvest() public {
        // Arrange
        uint256 stakeAmount = STAKE_AMOUNT;
        vm.startPrank(user1);
        mockToken.approve(address(trustlessVault), stakeAmount);
        trustlessVault.stake(stakeAmount);
        vm.stopPrank();

        // Wait for some time to accumulate rewards
        vm.warp(block.timestamp + 3600); // 1 hour

        uint256 initialBalance = mockToken.balanceOf(user1);

        // Act
        vm.startPrank(address(agent));
        trustlessVault.harvest(user1);
        vm.stopPrank();

        // Assert
        uint256 finalBalance = mockToken.balanceOf(user1);
        assertTrue(finalBalance > initialBalance, "User should receive rewards");
    }

    function testMultipleUsersStaking() public {
        // Arrange
        uint256 stakeAmount1 = STAKE_AMOUNT;
        uint256 stakeAmount2 = STAKE_AMOUNT / 2;

        // User1 stakes
        vm.startPrank(user1);
        mockToken.approve(address(trustlessVault), stakeAmount1);
        trustlessVault.stake(stakeAmount1);
        vm.stopPrank();

        // User2 stakes
        vm.startPrank(user2);
        mockToken.approve(address(trustlessVault), stakeAmount2);
        trustlessVault.stake(stakeAmount2);
        vm.stopPrank();

        // Assert
        assertEq(trustlessVault.stakedAmount(user1), stakeAmount1);
        assertEq(trustlessVault.stakedAmount(user2), stakeAmount2);
        assertEq(trustlessVault.totalStaked(), stakeAmount1 + stakeAmount2);
    }

    function testHarvestRewardCalculation() public {
        // Arrange
        uint256 stakeAmount = STAKE_AMOUNT;
        vm.startPrank(user1);
        mockToken.approve(address(trustlessVault), stakeAmount);
        trustlessVault.stake(stakeAmount);
        vm.stopPrank();

        // Act
        uint256 pendingReward = trustlessVault.getPendingReward(user1);

        // Assert
        uint256 expectedReward = (stakeAmount * 1000) / 1000000; // 0.1% of staked amount
        assertEq(pendingReward, expectedReward);
    }

    function testAgentRegistration() public view {
        // Assert
        assertTrue(identityRegistry.isAgentRegistered(address(agent)));
        assertEq(reputationRegistry.reputationOf(address(agent)), 1000);
        assertTrue(validationRegistry.isAgentValidated(address(agent), address(trustlessVault)));
    }

    function testUnstake() public {
        // Arrange
        uint256 stakeAmount = STAKE_AMOUNT;
        vm.startPrank(user1);
        mockToken.approve(address(trustlessVault), stakeAmount);
        trustlessVault.stake(stakeAmount);
        uint256 initialBalance = mockToken.balanceOf(user1);

        // Act
        trustlessVault.unstake(stakeAmount);

        // Assert
        assertEq(trustlessVault.stakedAmount(user1), 0);
        assertEq(trustlessVault.totalStaked(), 0);
        assertEq(mockToken.balanceOf(user1), initialBalance + stakeAmount);
    }

    function testValidationRegistryAdmin() public {
        // Test admin functions
        address newAdmin = makeAddr("newAdmin");

        // Only admin can set validation
        vm.expectRevert("ValidationRegistry: Only admin can perform this action");
        vm.prank(user1);
        validationRegistry.setValidation(address(agent), address(trustlessVault), false, 0, "Removing validation");

        // Admin can set validation
        validationRegistry.setValidation(address(agent), address(trustlessVault), false, 0, "Removing validation");
        assertFalse(validationRegistry.isAgentValidated(address(agent), address(trustlessVault)));

        // Admin can change admin
        validationRegistry.changeAdmin(newAdmin);
        assertEq(validationRegistry.admin(), newAdmin);
    }

    function testVaultOwnerFunctions() public {
        // Test owner functions
        address newRegistry = makeAddr("newRegistry");

        // Only owner can set validation registry
        vm.expectRevert();
        vm.prank(user1);
        trustlessVault.setValidationRegistry(newRegistry);

        // Owner can set validation registry
        trustlessVault.setValidationRegistry(newRegistry);
        // Note: This will fail because newRegistry is not a contract, but the test shows the access control works
    }

    function testAgentOwnerFunctions() public {
        // Test agent owner functions

        // Only owner can call harvest
        vm.expectRevert();
        vm.prank(user1);
        agent.callHarvest(address(trustlessVault), user1);

        // Owner can call harvest (after setting up staking)
        uint256 stakeAmount = STAKE_AMOUNT;
        vm.startPrank(user1);
        mockToken.approve(address(trustlessVault), stakeAmount);
        trustlessVault.stake(stakeAmount);
        vm.stopPrank();

        // The agent contract itself is the owner, so we need to call from the agent's owner
        vm.prank(deployer); // deployer is the owner of the agent
        agent.callHarvest(address(trustlessVault), user1);
    }

    function testEvents() public {
        // Test Staked event
        uint256 stakeAmount = STAKE_AMOUNT;
        vm.startPrank(user1);
        mockToken.approve(address(trustlessVault), stakeAmount);

        vm.expectEmit(true, false, false, true);
        emit TrustlessVault.Staked(user1, stakeAmount, block.timestamp);
        trustlessVault.stake(stakeAmount);
        vm.stopPrank();

        // Test Harvested event
        vm.expectEmit(true, true, false, true);
        uint256 expectedReward = (stakeAmount * 1000) / 1000000;
        emit TrustlessVault.Harvested(address(agent), user1, expectedReward, block.timestamp);

        vm.prank(address(agent));
        trustlessVault.harvest(user1);
    }

    function testZeroAmountStaking() public {
        // Test staking zero amount
        vm.startPrank(user1);
        vm.expectRevert("TrustlessVault: Amount must be greater than zero");
        trustlessVault.stake(0);
        vm.stopPrank();
    }

    function testAgentCallHarvestWithJobCommitment() public {
        // Arrange
        uint256 stakeAmount = STAKE_AMOUNT;
        vm.startPrank(user1);
        mockToken.approve(address(trustlessVault), stakeAmount);
        trustlessVault.stake(stakeAmount);
        vm.stopPrank();

        // Wait for some time to accumulate rewards
        vm.warp(block.timestamp + 3600); // 1 hour

        uint256 initialBalance = mockToken.balanceOf(user1);

        // Act - Use the agent's callHarvest function
        vm.prank(deployer); // deployer is the owner of the agent
        agent.callHarvest(address(trustlessVault), user1);

        // Assert
        uint256 finalBalance = mockToken.balanceOf(user1);
        assertTrue(finalBalance > initialBalance, "User should receive rewards");

        // Check that a job was committed
        bytes32[] memory agentJobs = agent.getAgentJobs();
        assertTrue(agentJobs.length > 0, "Agent should have committed jobs");
    }

    function testTimeDependentRewards() public {
        // Arrange
        uint256 stakeAmount = STAKE_AMOUNT;
        vm.startPrank(user1);
        mockToken.approve(address(trustlessVault), stakeAmount);
        trustlessVault.stake(stakeAmount);
        vm.stopPrank();

        // Wait for some time to pass
        vm.warp(block.timestamp + 3600); // 1 hour

        uint256 initialBalance = mockToken.balanceOf(user1);

        // Act
        vm.prank(address(agent));
        trustlessVault.harvest(user1);

        // Assert
        uint256 finalBalance = mockToken.balanceOf(user1);
        uint256 reward = finalBalance - initialBalance;

        // The reward should be time-dependent (1 token per second * 3600 seconds = 3600 tokens)
        // But scaled by user's stake proportion
        uint256 expectedReward = (3600 * 10 ** 18 * stakeAmount) / trustlessVault.totalStaked();
        assertApproxEqRel(reward, expectedReward, 0.01e18, "Reward should be time-dependent");
    }

    function testVaultPausability() public {
        // Test pausing
        trustlessVault.pause();

        vm.startPrank(user1);
        mockToken.approve(address(trustlessVault), STAKE_AMOUNT);
        vm.expectRevert();
        trustlessVault.stake(STAKE_AMOUNT);
        vm.stopPrank();

        // Test unpausing
        trustlessVault.unpause();

        vm.startPrank(user1);
        mockToken.approve(address(trustlessVault), STAKE_AMOUNT);
        trustlessVault.stake(STAKE_AMOUNT);
        vm.stopPrank();
    }

    function testJobCommitmentRegistry() public {
        // Test job commitment
        bytes32 jobHash = keccak256(abi.encodePacked("test_job", block.timestamp));

        vm.prank(address(agent));
        jobCommitmentRegistry.commitJob(jobHash, address(agent), address(trustlessVault));

        // Check job exists
        assertTrue(jobCommitmentRegistry.jobExists(jobHash), "Job should exist");

        // Test job completion
        bytes32 resultHash = keccak256(abi.encodePacked("test_result", block.timestamp));
        vm.prank(address(agent));
        jobCommitmentRegistry.completeJob(jobHash, resultHash);

        // Check job is completed
        JobCommitmentRegistry.JobCommitment memory commitment = jobCommitmentRegistry.getJobCommitment(jobHash);
        assertTrue(commitment.isCompleted, "Job should be completed");
        assertEq(commitment.resultHash, resultHash, "Result hash should match");
    }
}
