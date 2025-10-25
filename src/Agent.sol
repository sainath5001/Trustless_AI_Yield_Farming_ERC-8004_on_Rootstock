// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IdentityRegistry.sol";
import "./TrustlessVault.sol";
import "./JobCommitmentRegistry.sol";

/**
 * @title Agent
 * @dev An agent contract that can be registered and perform harvest operations with job commitments
 * @notice This contract represents an on-chain agent that can interact with the trustless vault system
 */
contract Agent is Ownable {
    // The identity registry for agent registration
    IdentityRegistry public immutable identityRegistry;

    // The job commitment registry for tracking AI work
    JobCommitmentRegistry public immutable jobCommitmentRegistry;

    // The agent's metadata URI
    string public metadataUri;

    // Whether the agent is registered in the identity registry
    bool public isRegistered;

    // Events
    event AgentRegistered(string metadataUri, uint256 timestamp);
    event HarvestCalled(address indexed vault, address indexed user, bytes32 jobHash, uint256 timestamp);
    event JobCommitted(bytes32 indexed jobHash, address indexed vault, address indexed user, uint256 timestamp);

    // Modifiers
    modifier onlyRegistered() {
        require(isRegistered, "Agent: Agent must be registered first");
        _;
    }

    /**
     * @dev Constructor
     * @param _identityRegistry The address of the identity registry
     * @param _jobCommitmentRegistry The address of the job commitment registry
     */
    constructor(address _identityRegistry, address _jobCommitmentRegistry) Ownable(msg.sender) {
        require(_identityRegistry != address(0), "Agent: Invalid identity registry address");
        require(_jobCommitmentRegistry != address(0), "Agent: Invalid job commitment registry address");

        identityRegistry = IdentityRegistry(_identityRegistry);
        jobCommitmentRegistry = JobCommitmentRegistry(_jobCommitmentRegistry);
    }

    /**
     * @dev Register the agent in the identity registry
     * @param _metadataUri The metadata URI for the agent
     */
    function register(string calldata _metadataUri) external onlyOwner {
        require(!isRegistered, "Agent: Agent already registered");
        require(bytes(_metadataUri).length > 0, "Agent: Metadata URI cannot be empty");

        // Register the agent in the identity registry (now uses msg.sender as agent)
        identityRegistry.registerAgent(_metadataUri);

        // Update local state
        metadataUri = _metadataUri;
        isRegistered = true;

        emit AgentRegistered(_metadataUri, block.timestamp);
    }

    /**
     * @dev Call harvest function on a vault for a specific user with job commitment
     * @param vault The address of the vault to harvest from
     * @param user The address of the user to harvest rewards for
     * @param jobHash The hash of the AI job being performed
     */
    function callHarvest(address vault, address user, bytes32 jobHash) external onlyOwner onlyRegistered {
        require(vault != address(0), "Agent: Invalid vault address");
        require(user != address(0), "Agent: Invalid user address");
        require(jobHash != bytes32(0), "Agent: Invalid job hash");

        // Commit to the job before performing it
        jobCommitmentRegistry.commitJob(jobHash, address(this), vault);

        // Call the harvest function on the vault
        TrustlessVault(vault).harvest(user);

        // Complete the job with a result hash
        bytes32 resultHash = keccak256(abi.encodePacked(vault, user, block.timestamp, "harvest_completed"));
        jobCommitmentRegistry.completeJob(jobHash, resultHash);

        emit HarvestCalled(vault, user, jobHash, block.timestamp);
        emit JobCommitted(jobHash, vault, user, block.timestamp);
    }

    /**
     * @dev Call harvest function on a vault for a specific user (legacy function for backward compatibility)
     * @param vault The address of the vault to harvest from
     * @param user The address of the user to harvest rewards for
     */
    function callHarvest(address vault, address user) external onlyOwner onlyRegistered {
        require(vault != address(0), "Agent: Invalid vault address");
        require(user != address(0), "Agent: Invalid user address");

        // Generate a job hash for the harvest operation
        bytes32 jobHash = keccak256(abi.encodePacked(vault, user, block.timestamp, "legacy_harvest"));

        // Commit to the job before performing it
        jobCommitmentRegistry.commitJob(jobHash, address(this), vault);

        // Call the harvest function on the vault
        TrustlessVault(vault).harvest(user);

        // Complete the job with a result hash
        bytes32 resultHash = keccak256(abi.encodePacked(vault, user, block.timestamp, "harvest_completed"));
        jobCommitmentRegistry.completeJob(jobHash, resultHash);

        emit HarvestCalled(vault, user, jobHash, block.timestamp);
        emit JobCommitted(jobHash, vault, user, block.timestamp);
    }

    /**
     * @dev Get the agent's information from the identity registry
     * @return The AgentCard struct containing agent information
     */
    function getAgentInfo() external view returns (IdentityRegistry.AgentCard memory) {
        require(isRegistered, "Agent: Agent not registered");
        return identityRegistry.getAgentCard(address(this));
    }

    /**
     * @dev Check if the agent is registered in the identity registry
     * @return True if registered, false otherwise
     */
    function checkRegistration() external view returns (bool) {
        return identityRegistry.isAgentRegistered(address(this));
    }

    /**
     * @dev Get the agent's address
     * @return The address of this agent contract
     */
    function getAgentAddress() external view returns (address) {
        return address(this);
    }

    /**
     * @dev Get jobs performed by this agent
     * @return Array of job hashes
     */
    function getAgentJobs() external view returns (bytes32[] memory) {
        return jobCommitmentRegistry.getJobsByAgent(address(this));
    }

    /**
     * @dev Get job commitment details
     * @param jobHash The hash of the job
     * @return The JobCommitment struct
     */
    function getJobCommitment(bytes32 jobHash) external view returns (JobCommitmentRegistry.JobCommitment memory) {
        return jobCommitmentRegistry.getJobCommitment(jobHash);
    }

    /**
     * @dev Get job attestations
     * @param jobHash The hash of the job
     * @return Array of ValidatorAttestation structs
     */
    function getJobAttestations(bytes32 jobHash)
        external
        view
        returns (JobCommitmentRegistry.ValidatorAttestation[] memory)
    {
        return jobCommitmentRegistry.getJobAttestations(jobHash);
    }
}
