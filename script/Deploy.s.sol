// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/IdentityRegistry.sol";
import "../src/ReputationRegistry.sol";
import "../src/ValidationRegistry.sol";
import "../src/MockToken.sol";
import "../src/TrustlessVault.sol";
import "../src/Agent.sol";

/**
 * @title Deploy
 * @dev Deployment script for the Trustless Yield Farming Bot system
 * @notice This script deploys all contracts and sets up the initial configuration
 */
contract Deploy is Script {
    // Contract instances
    IdentityRegistry public identityRegistry;
    ReputationRegistry public reputationRegistry;
    ValidationRegistry public validationRegistry;
    MockToken public mockToken;
    TrustlessVault public trustlessVault;
    JobCommitmentRegistry public jobCommitmentRegistry;
    Agent public agent;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying contracts with account:", deployer);
        console.log("Account balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy IdentityRegistry
        console.log("Deploying IdentityRegistry...");
        identityRegistry = new IdentityRegistry();
        console.log("IdentityRegistry deployed at:", address(identityRegistry));

        // 2. Deploy ReputationRegistry
        console.log("Deploying ReputationRegistry...");
        reputationRegistry = new ReputationRegistry();
        console.log("ReputationRegistry deployed at:", address(reputationRegistry));

        // 3. Deploy MockToken
        console.log("Deploying MockToken...");
        mockToken = new MockToken();
        console.log("MockToken deployed at:", address(mockToken));
        console.log("MockToken balance of deployer:", mockToken.balanceOf(deployer));

        // 4. Deploy ValidationRegistry
        console.log("Deploying ValidationRegistry...");
        validationRegistry = new ValidationRegistry(deployer, address(mockToken), 1000 * 10 ** 18, 30 days); // 1000 tokens min stake, 30 days expiry
        console.log("ValidationRegistry deployed at:", address(validationRegistry));

        // 5. Deploy TrustlessVault
        console.log("Deploying TrustlessVault...");
        trustlessVault = new TrustlessVault(address(mockToken), address(validationRegistry), 1 * 10 ** 18); // 1 token per second reward rate
        console.log("TrustlessVault deployed at:", address(trustlessVault));

        // 6. Deploy JobCommitmentRegistry
        console.log("Deploying JobCommitmentRegistry...");
        jobCommitmentRegistry = new JobCommitmentRegistry();
        console.log("JobCommitmentRegistry deployed at:", address(jobCommitmentRegistry));

        // 7. Deploy Agent
        console.log("Deploying Agent...");
        agent = new Agent(address(identityRegistry), address(jobCommitmentRegistry));
        console.log("Agent deployed at:", address(agent));

        vm.stopBroadcast();

        // 8. Register agent in IdentityRegistry
        console.log("Registering agent in IdentityRegistry...");
        vm.startBroadcast(deployerPrivateKey);

        string memory metadataUri = "https://example.com/agent-metadata.json";
        agent.register(metadataUri);
        console.log("Agent registered with metadata URI:", metadataUri);

        // 9. Set agent validation in ValidationRegistry
        console.log("Setting agent validation in ValidationRegistry...");
        validationRegistry.setValidation(
            address(agent), address(trustlessVault), true, 1000 * 10 ** 18, "Initial validation for testing"
        );
        console.log("Agent validation set for vault");

        // 10. Set reputation for the agent
        console.log("Setting agent reputation...");
        reputationRegistry.setReputation(address(agent), 1000, "Initial high reputation score"); // High reputation score
        console.log("Agent reputation set to 1000");

        vm.stopBroadcast();

        // Log all deployed addresses
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("IdentityRegistry:", address(identityRegistry));
        console.log("ReputationRegistry:", address(reputationRegistry));
        console.log("ValidationRegistry:", address(validationRegistry));
        console.log("MockToken:", address(mockToken));
        console.log("TrustlessVault:", address(trustlessVault));
        console.log("JobCommitmentRegistry:", address(jobCommitmentRegistry));
        console.log("Deployer:", deployer);
        console.log("========================\n");

        // Verify the setup
        console.log("=== VERIFICATION ===");
        console.log("Agent registered:", identityRegistry.isAgentRegistered(address(agent)));
        console.log(
            "Agent validated for vault:", validationRegistry.isAgentValidated(address(agent), address(trustlessVault))
        );
        console.log("Agent reputation:", reputationRegistry.reputationOf(address(agent)));
        console.log("MockToken balance:", mockToken.balanceOf(deployer));
        console.log("===================\n");
    }
}
