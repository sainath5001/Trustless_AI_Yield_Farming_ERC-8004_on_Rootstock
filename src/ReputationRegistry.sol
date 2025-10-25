// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ReputationRegistry
 * @dev ERC-8004 Reputation Registry for managing agent reputation scores
 * @notice This contract maintains numeric reputation scores for each agent with proper access control
 */
contract ReputationRegistry is Ownable {
    // Attestor role for reputation updates
    mapping(address => bool) public attestors;

    // Mapping from agent address to reputation score
    mapping(address => uint256) private _reputationScores;

    // Array of all agents with reputation scores
    address[] private _agentsWithReputation;

    // Mapping to track if an agent has a reputation score
    mapping(address => bool) private _hasReputation;

    // Reputation update history for provenance
    struct ReputationUpdate {
        address agent;
        uint256 oldScore;
        uint256 newScore;
        address attestor;
        uint256 timestamp;
        string reason;
    }

    ReputationUpdate[] private _reputationHistory;

    // Events
    event ReputationSet(
        address indexed agent,
        uint256 oldScore,
        uint256 newScore,
        address indexed attestor,
        string reason,
        uint256 timestamp
    );
    event AttestorAdded(address indexed attestor, uint256 timestamp);
    event AttestorRemoved(address indexed attestor, uint256 timestamp);

    // Modifiers
    modifier onlyAttestor() {
        require(
            attestors[msg.sender] || msg.sender == owner(), "ReputationRegistry: Only attestors can update reputation"
        );
        _;
    }

    /**
     * @dev Constructor
     */
    constructor() Ownable(msg.sender) {
        // Owner is automatically an attestor
        attestors[msg.sender] = true;
    }

    /**
     * @dev Set the reputation score for an agent (only attestors)
     * @param agent The address of the agent
     * @param score The reputation score to set
     * @param reason The reason for the reputation update
     */
    function setReputation(address agent, uint256 score, string calldata reason) external onlyAttestor {
        require(agent != address(0), "ReputationRegistry: Invalid agent address");
        require(bytes(reason).length > 0, "ReputationRegistry: Reason cannot be empty");

        uint256 oldScore = _reputationScores[agent];

        // If this is the first time setting reputation for this agent, add to array
        if (!_hasReputation[agent]) {
            _agentsWithReputation.push(agent);
            _hasReputation[agent] = true;
        }

        _reputationScores[agent] = score;

        // Record the update in history for provenance
        _reputationHistory.push(
            ReputationUpdate({
                agent: agent,
                oldScore: oldScore,
                newScore: score,
                attestor: msg.sender,
                timestamp: block.timestamp,
                reason: reason
            })
        );

        emit ReputationSet(agent, oldScore, score, msg.sender, reason, block.timestamp);
    }

    /**
     * @dev Add an attestor (only owner)
     * @param attestor The address of the attestor to add
     */
    function addAttestor(address attestor) external onlyOwner {
        require(attestor != address(0), "ReputationRegistry: Invalid attestor address");
        require(!attestors[attestor], "ReputationRegistry: Attestor already exists");

        attestors[attestor] = true;
        emit AttestorAdded(attestor, block.timestamp);
    }

    /**
     * @dev Remove an attestor (only owner)
     * @param attestor The address of the attestor to remove
     */
    function removeAttestor(address attestor) external onlyOwner {
        require(attestor != address(0), "ReputationRegistry: Invalid attestor address");
        require(attestors[attestor], "ReputationRegistry: Attestor does not exist");
        require(attestor != owner(), "ReputationRegistry: Cannot remove owner attestor");

        attestors[attestor] = false;
        emit AttestorRemoved(attestor, block.timestamp);
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

    /**
     * @dev Get reputation update history for provenance
     * @return Array of all ReputationUpdate structs
     */
    function getReputationHistory() external view returns (ReputationUpdate[] memory) {
        return _reputationHistory;
    }

    /**
     * @dev Get reputation update history for a specific agent
     * @param agent The address of the agent
     * @return Array of ReputationUpdate structs for the agent
     */
    function getReputationHistoryForAgent(address agent) external view returns (ReputationUpdate[] memory) {
        uint256 count = 0;

        // Count matching entries
        for (uint256 i = 0; i < _reputationHistory.length; i++) {
            if (_reputationHistory[i].agent == agent) {
                count++;
            }
        }

        // Create result array
        ReputationUpdate[] memory result = new ReputationUpdate[](count);
        uint256 index = 0;

        // Populate result array
        for (uint256 i = 0; i < _reputationHistory.length; i++) {
            if (_reputationHistory[i].agent == agent) {
                result[index] = _reputationHistory[i];
                index++;
            }
        }

        return result;
    }

    /**
     * @dev Get reputation update history for a specific attestor
     * @param attestor The address of the attestor
     * @return Array of ReputationUpdate structs by the attestor
     */
    function getReputationHistoryForAttestor(address attestor) external view returns (ReputationUpdate[] memory) {
        uint256 count = 0;

        // Count matching entries
        for (uint256 i = 0; i < _reputationHistory.length; i++) {
            if (_reputationHistory[i].attestor == attestor) {
                count++;
            }
        }

        // Create result array
        ReputationUpdate[] memory result = new ReputationUpdate[](count);
        uint256 index = 0;

        // Populate result array
        for (uint256 i = 0; i < _reputationHistory.length; i++) {
            if (_reputationHistory[i].attestor == attestor) {
                result[index] = _reputationHistory[i];
                index++;
            }
        }

        return result;
    }

    /**
     * @dev Get total number of attestors
     * @return The number of attestors
     */
    function getTotalAttestors() external view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < _agentsWithReputation.length; i++) {
            if (attestors[_agentsWithReputation[i]]) {
                count++;
            }
        }
        return count;
    }
}
