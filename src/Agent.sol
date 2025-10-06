// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IdentityRegistry.sol";
import "./TrustlessVault.sol";

/**
 * @title Agent
 * @dev An agent contract that can be registered and perform harvest operations
 * @notice This contract represents an on-chain agent that can interact with the trustless vault system
 */
contract Agent is Ownable {
    // The identity registry for agent registration
    IdentityRegistry public immutable identityRegistry;

    // The agent's metadata URI
    string public metadataUri;

    // Whether the agent is registered in the identity registry
    bool public isRegistered;

    // Events
    event AgentRegistered(string metadataUri, uint256 timestamp);
    event HarvestCalled(address indexed vault, address indexed user, uint256 timestamp);

    // Modifiers
    modifier onlyRegistered() {
        require(isRegistered, "Agent: Agent must be registered first");
        _;
    }

    /**
     * @dev Constructor
     * @param _identityRegistry The address of the identity registry
     */
    constructor(address _identityRegistry) Ownable(msg.sender) {
        require(_identityRegistry != address(0), "Agent: Invalid identity registry address");
        identityRegistry = IdentityRegistry(_identityRegistry);
    }

    /**
     * @dev Register the agent in the identity registry
     * @param _metadataUri The metadata URI for the agent
     */
    function register(string calldata _metadataUri) external onlyOwner {
        require(!isRegistered, "Agent: Agent already registered");
        require(bytes(_metadataUri).length > 0, "Agent: Metadata URI cannot be empty");

        // Register the agent in the identity registry
        identityRegistry.registerAgent(address(this), _metadataUri);

        // Update local state
        metadataUri = _metadataUri;
        isRegistered = true;

        emit AgentRegistered(_metadataUri, block.timestamp);
    }

    /**
     * @dev Call harvest function on a vault for a specific user
     * @param vault The address of the vault to harvest from
     * @param user The address of the user to harvest rewards for
     */
    function callHarvest(address vault, address user) external onlyOwner onlyRegistered {
        require(vault != address(0), "Agent: Invalid vault address");
        require(user != address(0), "Agent: Invalid user address");

        // Call the harvest function on the vault
        TrustlessVault(vault).harvest(user);

        emit HarvestCalled(vault, user, block.timestamp);
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
     * @dev Get the agent's owner address
     * @return The address of the agent owner
     */
    function getOwner() external view returns (address) {
        return owner();
    }
}
