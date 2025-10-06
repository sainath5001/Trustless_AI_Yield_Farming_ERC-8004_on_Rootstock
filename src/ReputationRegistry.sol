// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ReputationRegistry
 * @dev ERC-8004 Reputation Registry for managing agent reputation scores
 * @notice This contract maintains numeric reputation scores for each agent
 */
contract ReputationRegistry {
    // Mapping from agent address to reputation score
    mapping(address => uint256) private _reputationScores;

    // Array of all agents with reputation scores
    address[] private _agentsWithReputation;

    // Mapping to track if an agent has a reputation score
    mapping(address => bool) private _hasReputation;

    // Events
    event ReputationSet(address indexed agent, uint256 score, uint256 timestamp);

    /**
     * @dev Set the reputation score for an agent
     * @param agent The address of the agent
     * @param score The reputation score to set
     */
    function setReputation(address agent, uint256 score) external {
        require(agent != address(0), "ReputationRegistry: Invalid agent address");

        // If this is the first time setting reputation for this agent, add to array
        if (!_hasReputation[agent]) {
            _agentsWithReputation.push(agent);
            _hasReputation[agent] = true;
        }

        _reputationScores[agent] = score;

        emit ReputationSet(agent, score, block.timestamp);
    }

    /**
     * @dev Get the reputation score of an agent
     * @param agent The address of the agent
     * @return The reputation score of the agent (0 if not set)
     */
    function reputationOf(address agent) external view returns (uint256) {
        return _reputationScores[agent];
    }

    /**
     * @dev Check if an agent has a reputation score set
     * @param agent The address of the agent
     * @return True if the agent has a reputation score, false otherwise
     */
    function hasReputation(address agent) external view returns (bool) {
        return _hasReputation[agent];
    }

    /**
     * @dev Get the total number of agents with reputation scores
     * @return The number of agents with reputation scores
     */
    function getTotalAgentsWithReputation() external view returns (uint256) {
        return _agentsWithReputation.length;
    }

    /**
     * @dev Get all agents with reputation scores
     * @return Array of all agent addresses that have reputation scores
     */
    function getAllAgentsWithReputation() external view returns (address[] memory) {
        return _agentsWithReputation;
    }

    /**
     * @dev Get reputation scores for multiple agents
     * @param agents Array of agent addresses
     * @return Array of reputation scores corresponding to the input agents
     */
    function getReputationScores(address[] calldata agents) external view returns (uint256[] memory) {
        uint256[] memory scores = new uint256[](agents.length);
        for (uint256 i = 0; i < agents.length; i++) {
            scores[i] = _reputationScores[agents[i]];
        }
        return scores;
    }
}
