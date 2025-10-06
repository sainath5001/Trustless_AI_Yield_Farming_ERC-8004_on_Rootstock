// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ValidationRegistry
 * @dev ERC-8004 Validation Registry for managing agent validation for specific vaults
 * @notice This contract maintains which agents are validated to act on specific vaults
 */
contract ValidationRegistry {
    // Admin address with special privileges
    address public admin;

    // Mapping from (agent, vault) to validation status
    mapping(address => mapping(address => bool)) private _validations;

    // Array of all validation entries for enumeration
    struct ValidationEntry {
        address agent;
        address vault;
        bool validated;
        uint256 timestamp;
    }

    ValidationEntry[] private _validationEntries;

    // Events
    event ValidationSet(address indexed agent, address indexed vault, bool validated, uint256 timestamp);
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);

    // Modifiers
    modifier onlyAdmin() {
        require(msg.sender == admin, "ValidationRegistry: Only admin can perform this action");
        _;
    }

    /**
     * @dev Constructor sets the initial admin
     * @param _admin The address of the initial admin
     */
    constructor(address _admin) {
        require(_admin != address(0), "ValidationRegistry: Invalid admin address");
        admin = _admin;
    }

    /**
     * @dev Set validation status for an agent on a specific vault
     * @param agent The address of the agent
     * @param vault The address of the vault
     * @param validated Whether the agent is validated for this vault
     */
    function setValidation(address agent, address vault, bool validated) external onlyAdmin {
        require(agent != address(0), "ValidationRegistry: Invalid agent address");
        require(vault != address(0), "ValidationRegistry: Invalid vault address");

        _validations[agent][vault] = validated;

        // Add to validation entries for enumeration
        _validationEntries.push(
            ValidationEntry({agent: agent, vault: vault, validated: validated, timestamp: block.timestamp})
        );

        emit ValidationSet(agent, vault, validated, block.timestamp);
    }

    /**
     * @dev Check if an agent is validated for a specific vault
     * @param agent The address of the agent
     * @param vault The address of the vault
     * @return True if the agent is validated for this vault, false otherwise
     */
    function isAgentValidated(address agent, address vault) external view returns (bool) {
        return _validations[agent][vault];
    }

    /**
     * @dev Change the admin address
     * @param newAdmin The address of the new admin
     */
    function changeAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "ValidationRegistry: Invalid new admin address");
        require(newAdmin != admin, "ValidationRegistry: New admin must be different");

        address oldAdmin = admin;
        admin = newAdmin;

        emit AdminChanged(oldAdmin, newAdmin);
    }

    /**
     * @dev Get the total number of validation entries
     * @return The number of validation entries
     */
    function getTotalValidationEntries() external view returns (uint256) {
        return _validationEntries.length;
    }

    /**
     * @dev Get all validation entries
     * @return Array of all ValidationEntry structs
     */
    function getAllValidationEntries() external view returns (ValidationEntry[] memory) {
        return _validationEntries;
    }

    /**
     * @dev Get validation entries for a specific agent
     * @param agent The address of the agent
     * @return Array of ValidationEntry structs for the agent
     */
    function getValidationEntriesForAgent(address agent) external view returns (ValidationEntry[] memory) {
        uint256 count = 0;

        // Count matching entries
        for (uint256 i = 0; i < _validationEntries.length; i++) {
            if (_validationEntries[i].agent == agent) {
                count++;
            }
        }

        // Create result array
        ValidationEntry[] memory result = new ValidationEntry[](count);
        uint256 index = 0;

        // Populate result array
        for (uint256 i = 0; i < _validationEntries.length; i++) {
            if (_validationEntries[i].agent == agent) {
                result[index] = _validationEntries[i];
                index++;
            }
        }

        return result;
    }

    /**
     * @dev Get validation entries for a specific vault
     * @param vault The address of the vault
     * @return Array of ValidationEntry structs for the vault
     */
    function getValidationEntriesForVault(address vault) external view returns (ValidationEntry[] memory) {
        uint256 count = 0;

        // Count matching entries
        for (uint256 i = 0; i < _validationEntries.length; i++) {
            if (_validationEntries[i].vault == vault) {
                count++;
            }
        }

        // Create result array
        ValidationEntry[] memory result = new ValidationEntry[](count);
        uint256 index = 0;

        // Populate result array
        for (uint256 i = 0; i < _validationEntries.length; i++) {
            if (_validationEntries[i].vault == vault) {
                result[index] = _validationEntries[i];
                index++;
            }
        }

        return result;
    }
}
