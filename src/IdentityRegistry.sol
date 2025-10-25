// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title IdentityRegistry
 * @dev ERC-8004 Identity Registry for managing agent identities
 * @notice This contract stores agent identity information including metadata URIs with proper verification
 */
contract IdentityRegistry is Ownable {
    /**
     * @dev Struct representing an agent's identity card
     * @param agent The address of the agent
     * @param metadataUri URI containing agent metadata
     * @param registeredAt Timestamp when the agent was registered
     * @param lastUpdated Timestamp when the agent was last updated
     * @param isActive Whether the agent is currently active
     */
    struct AgentCard {
        address agent;
        string metadataUri;
        uint256 registeredAt;
        uint256 lastUpdated;
        bool isActive;
    }

    // Mapping from agent address to AgentCard
    mapping(address => AgentCard) private _agentCards;

    // Array of all registered agent addresses
    address[] private _registeredAgents;

    // Mapping to check if an agent is registered
    mapping(address => bool) private _isRegistered;

    // Events
    event AgentRegistered(address indexed agent, string metadataUri, uint256 timestamp);
    event AgentUpdated(address indexed agent, string oldMetadataUri, string newMetadataUri, uint256 timestamp);
    event AgentDeregistered(address indexed agent, uint256 timestamp);
    event AgentReactivated(address indexed agent, uint256 timestamp);

    // Modifiers
    modifier onlyAgentOrOwner(address agent) {
        require(
            msg.sender == agent || msg.sender == owner(),
            "IdentityRegistry: Only agent or owner can perform this action"
        );
        _;
    }

    modifier onlyRegisteredAgent(address agent) {
        require(_isRegistered[agent], "IdentityRegistry: Agent not registered");
        _;
    }

    /**
     * @dev Constructor
     */
    constructor() Ownable(msg.sender) {
        // Owner is automatically set by Ownable constructor
    }

    /**
     * @dev Register a new agent with metadata (only the agent itself can register)
     * @param metadataUri URI containing agent metadata
     */
    function registerAgent(string calldata metadataUri) external {
        address agent = msg.sender;
        require(agent != address(0), "IdentityRegistry: Invalid agent address");
        require(!_isRegistered[agent], "IdentityRegistry: Agent already registered");
        require(bytes(metadataUri).length > 0, "IdentityRegistry: Metadata URI cannot be empty");

        AgentCard memory newCard = AgentCard({
            agent: agent,
            metadataUri: metadataUri,
            registeredAt: block.timestamp,
            lastUpdated: block.timestamp,
            isActive: true
        });

        _agentCards[agent] = newCard;
        _registeredAgents.push(agent);
        _isRegistered[agent] = true;

        emit AgentRegistered(agent, metadataUri, block.timestamp);
    }

    /**
     * @dev Update agent metadata (only the agent itself or owner can update)
     * @param agent The address of the agent to update
     * @param newMetadataUri New metadata URI
     */
    function updateAgent(address agent, string calldata newMetadataUri)
        external
        onlyAgentOrOwner(agent)
        onlyRegisteredAgent(agent)
    {
        require(bytes(newMetadataUri).length > 0, "IdentityRegistry: Metadata URI cannot be empty");
        require(_agentCards[agent].isActive, "IdentityRegistry: Agent is not active");

        string memory oldMetadataUri = _agentCards[agent].metadataUri;

        _agentCards[agent].metadataUri = newMetadataUri;
        _agentCards[agent].lastUpdated = block.timestamp;

        emit AgentUpdated(agent, oldMetadataUri, newMetadataUri, block.timestamp);
    }

    /**
     * @dev Deregister an agent (only the agent itself or owner can deregister)
     * @param agent The address of the agent to deregister
     */
    function deregisterAgent(address agent) external onlyAgentOrOwner(agent) onlyRegisteredAgent(agent) {
        require(_agentCards[agent].isActive, "IdentityRegistry: Agent is already inactive");

        _agentCards[agent].isActive = false;
        _agentCards[agent].lastUpdated = block.timestamp;

        emit AgentDeregistered(agent, block.timestamp);
    }

    /**
     * @dev Reactivate a deregistered agent (only owner can reactivate)
     * @param agent The address of the agent to reactivate
     */
    function reactivateAgent(address agent) external onlyOwner onlyRegisteredAgent(agent) {
        require(!_agentCards[agent].isActive, "IdentityRegistry: Agent is already active");

        _agentCards[agent].isActive = true;
        _agentCards[agent].lastUpdated = block.timestamp;

        emit AgentReactivated(agent, block.timestamp);
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
     * @dev Check if an agent is active
     * @param agent The address of the agent
     * @return True if the agent is registered and active, false otherwise
     */
    function isAgentActive(address agent) external view returns (bool) {
        return _isRegistered[agent] && _agentCards[agent].isActive;
    }

    /**
     * @dev Get the total number of registered agents
     * @return The number of registered agents
     */
    function getTotalAgents() external view returns (uint256) {
        return _registeredAgents.length;
    }

    /**
     * @dev Get the total number of active agents
     * @return The number of active agents
     */
    function getTotalActiveAgents() external view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < _registeredAgents.length; i++) {
            if (_agentCards[_registeredAgents[i]].isActive) {
                count++;
            }
        }
        return count;
    }

    /**
     * @dev Get all registered agent addresses
     * @return Array of all registered agent addresses
     */
    function getAllRegisteredAgents() external view returns (address[] memory) {
        return _registeredAgents;
    }

    /**
     * @dev Get all active agent addresses
     * @return Array of all active agent addresses
     */
    function getAllActiveAgents() external view returns (address[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < _registeredAgents.length; i++) {
            if (_agentCards[_registeredAgents[i]].isActive) {
                count++;
            }
        }

        address[] memory activeAgents = new address[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < _registeredAgents.length; i++) {
            if (_agentCards[_registeredAgents[i]].isActive) {
                activeAgents[index] = _registeredAgents[i];
                index++;
            }
        }

        return activeAgents;
    }

    /**
     * @dev Get agent information for multiple agents
     * @param agents Array of agent addresses
     * @return Array of AgentCard structs corresponding to the input agents
     */
    function getAgentCards(address[] calldata agents) external view returns (AgentCard[] memory) {
        AgentCard[] memory cards = new AgentCard[](agents.length);
        for (uint256 i = 0; i < agents.length; i++) {
            if (_isRegistered[agents[i]]) {
                cards[i] = _agentCards[agents[i]];
            }
        }
        return cards;
    }
}
