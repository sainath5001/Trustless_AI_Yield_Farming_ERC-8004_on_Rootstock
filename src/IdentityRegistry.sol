// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IdentityRegistry
 * @dev ERC-8004 Identity Registry for managing agent identities
 * @notice This contract stores agent identity information including metadata URIs
 */
contract IdentityRegistry {
    /**
     * @dev Struct representing an agent's identity card
     * @param agent The address of the agent
     * @param metadataUri URI containing agent metadata
     * @param registeredAt Timestamp when the agent was registered
     */
    struct AgentCard {
        address agent;
        string metadataUri;
        uint256 registeredAt;
    }

    // Mapping from agent address to AgentCard
    mapping(address => AgentCard) private _agentCards;

    // Array of all registered agent addresses
    address[] private _registeredAgents;

    // Mapping to check if an agent is registered
    mapping(address => bool) private _isRegistered;

    // Events
    event AgentRegistered(address indexed agent, string metadataUri, uint256 timestamp);

    /**
     * @dev Register a new agent with metadata
     * @param agent The address of the agent to register
     * @param metadataUri URI containing agent metadata
     */
    function registerAgent(address agent, string calldata metadataUri) external {
        require(agent != address(0), "IdentityRegistry: Invalid agent address");
        require(!_isRegistered[agent], "IdentityRegistry: Agent already registered");
        require(bytes(metadataUri).length > 0, "IdentityRegistry: Metadata URI cannot be empty");

        AgentCard memory newCard = AgentCard({agent: agent, metadataUri: metadataUri, registeredAt: block.timestamp});

        _agentCards[agent] = newCard;
        _registeredAgents.push(agent);
        _isRegistered[agent] = true;

        emit AgentRegistered(agent, metadataUri, block.timestamp);
    }

    /**
     * @dev Get the agent card for a specific agent
     * @param agent The address of the agent
     * @return The AgentCard struct containing agent information
     */
    function getAgentCard(address agent) external view returns (AgentCard memory) {
        require(_isRegistered[agent], "IdentityRegistry: Agent not registered");
        return _agentCards[agent];
    }

    /**
     * @dev Check if an agent is registered
     * @param agent The address of the agent
     * @return True if the agent is registered, false otherwise
     */
    function isAgentRegistered(address agent) external view returns (bool) {
        return _isRegistered[agent];
    }

    /**
     * @dev Get the total number of registered agents
     * @return The number of registered agents
     */
    function getTotalAgents() external view returns (uint256) {
        return _registeredAgents.length;
    }

    /**
     * @dev Get all registered agent addresses
     * @return Array of all registered agent addresses
     */
    function getAllRegisteredAgents() external view returns (address[] memory) {
        return _registeredAgents;
    }
}
