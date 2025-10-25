// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ValidationRegistry
 * @dev ERC-8004 Validation Registry for managing agent validation for specific vaults
 * @notice This contract maintains which agents are validated to act on specific vaults with provenance and expiry
 */
contract ValidationRegistry is Ownable {
    // Admin address with special privileges
    address public admin;

    // Validation token for staking requirements
    IERC20 public validationToken;

    // Minimum stake required for validation
    uint256 public minStakeAmount;

    // Validation expiry duration (in seconds)
    uint256 public validationExpiryDuration;

    // Mapping from (agent, vault) to validation status
    mapping(address => mapping(address => bool)) private _validations;

    // Mapping from (agent, vault) to validation expiry timestamp
    mapping(address => mapping(address => uint256)) private _validationExpiry;

    // Mapping from (agent, vault) to stake amount
    mapping(address => mapping(address => uint256)) private _validationStakes;

    // Array of all validation entries for enumeration
    struct ValidationEntry {
        address agent;
        address vault;
        bool validated;
        uint256 stakeAmount;
        uint256 expiryTimestamp;
        address validator;
        uint256 timestamp;
        string reason;
    }

    ValidationEntry[] private _validationEntries;

    // Events
    event ValidationSet(
        address indexed agent,
        address indexed vault,
        bool validated,
        uint256 stakeAmount,
        uint256 expiryTimestamp,
        address indexed validator,
        string reason,
        uint256 timestamp
    );
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);
    event ValidationTokenUpdated(address indexed oldToken, address indexed newToken, uint256 timestamp);
    event MinStakeAmountUpdated(uint256 oldAmount, uint256 newAmount, uint256 timestamp);
    event ValidationExpiryDurationUpdated(uint256 oldDuration, uint256 newDuration, uint256 timestamp);

    // Modifiers
    modifier onlyAdmin() {
        require(msg.sender == admin, "ValidationRegistry: Only admin can perform this action");
        _;
    }

    /**
     * @dev Constructor sets the initial admin and configuration
     * @param _admin The address of the initial admin
     * @param _validationToken The address of the validation token for staking
     * @param _minStakeAmount The minimum stake amount required for validation
     * @param _validationExpiryDuration The duration for validation expiry (in seconds)
     */
    constructor(address _admin, address _validationToken, uint256 _minStakeAmount, uint256 _validationExpiryDuration)
        Ownable(msg.sender)
    {
        require(_admin != address(0), "ValidationRegistry: Invalid admin address");
        require(_validationToken != address(0), "ValidationRegistry: Invalid validation token address");
        require(_minStakeAmount > 0, "ValidationRegistry: Min stake amount must be greater than zero");
        require(_validationExpiryDuration > 0, "ValidationRegistry: Expiry duration must be greater than zero");

        admin = _admin;
        validationToken = IERC20(_validationToken);
        minStakeAmount = _minStakeAmount;
        validationExpiryDuration = _validationExpiryDuration;
    }

    /**
     * @dev Set validation status for an agent on a specific vault with stake and expiry
     * @param agent The address of the agent
     * @param vault The address of the vault
     * @param validated Whether the agent is validated for this vault
     * @param stakeAmount The amount of tokens to stake for validation
     * @param reason The reason for the validation decision
     */
    function setValidation(address agent, address vault, bool validated, uint256 stakeAmount, string calldata reason)
        external
        onlyAdmin
    {
        require(agent != address(0), "ValidationRegistry: Invalid agent address");
        require(vault != address(0), "ValidationRegistry: Invalid vault address");
        require(bytes(reason).length > 0, "ValidationRegistry: Reason cannot be empty");

        if (validated) {
            require(stakeAmount >= minStakeAmount, "ValidationRegistry: Stake amount below minimum");
            require(
                validationToken.balanceOf(msg.sender) >= stakeAmount,
                "ValidationRegistry: Insufficient validation token balance"
            );

            // Transfer stake from admin to contract
            validationToken.transferFrom(msg.sender, address(this), stakeAmount);

            // Update stake amount
            _validationStakes[agent][vault] = stakeAmount;
        } else {
            // If removing validation, return the stake
            uint256 currentStake = _validationStakes[agent][vault];
            if (currentStake > 0) {
                validationToken.transfer(msg.sender, currentStake);
                _validationStakes[agent][vault] = 0;
            }
        }

        _validations[agent][vault] = validated;

        // Set expiry timestamp
        uint256 expiryTimestamp = validated ? block.timestamp + validationExpiryDuration : 0;
        _validationExpiry[agent][vault] = expiryTimestamp;

        // Add to validation entries for enumeration
        _validationEntries.push(
            ValidationEntry({
                agent: agent,
                vault: vault,
                validated: validated,
                stakeAmount: stakeAmount,
                expiryTimestamp: expiryTimestamp,
                validator: msg.sender,
                timestamp: block.timestamp,
                reason: reason
            })
        );

        emit ValidationSet(agent, vault, validated, stakeAmount, expiryTimestamp, msg.sender, reason, block.timestamp);
    }

    /**
     * @dev Check if an agent is validated for a specific vault (considering expiry)
     * @param agent The address of the agent
     * @param vault The address of the vault
     * @return True if the agent is validated for this vault and not expired, false otherwise
     */
    function isAgentValidated(address agent, address vault) external view returns (bool) {
        if (!_validations[agent][vault]) {
            return false;
        }

        // Check if validation has expired
        uint256 expiryTimestamp = _validationExpiry[agent][vault];
        if (expiryTimestamp > 0 && block.timestamp > expiryTimestamp) {
            return false;
        }

        return true;
    }

    /**
     * @dev Renew validation for an agent (only admin)
     * @param agent The address of the agent
     * @param vault The address of the vault
     * @param additionalStake Additional stake amount (can be 0)
     * @param reason The reason for renewal
     */
    function renewValidation(address agent, address vault, uint256 additionalStake, string calldata reason)
        external
        onlyAdmin
    {
        require(_validations[agent][vault], "ValidationRegistry: Agent not currently validated");
        require(bytes(reason).length > 0, "ValidationRegistry: Reason cannot be empty");

        if (additionalStake > 0) {
            require(
                validationToken.balanceOf(msg.sender) >= additionalStake,
                "ValidationRegistry: Insufficient validation token balance"
            );
            validationToken.transferFrom(msg.sender, address(this), additionalStake);
            _validationStakes[agent][vault] += additionalStake;
        }

        // Extend expiry
        _validationExpiry[agent][vault] = block.timestamp + validationExpiryDuration;

        // Add renewal entry
        _validationEntries.push(
            ValidationEntry({
                agent: agent,
                vault: vault,
                validated: true,
                stakeAmount: additionalStake,
                expiryTimestamp: _validationExpiry[agent][vault],
                validator: msg.sender,
                timestamp: block.timestamp,
                reason: reason
            })
        );

        emit ValidationSet(
            agent, vault, true, additionalStake, _validationExpiry[agent][vault], msg.sender, reason, block.timestamp
        );
    }

    /**
     * @dev Get validation details for an agent and vault
     * @param agent The address of the agent
     * @param vault The address of the vault
     * @return isValidated Whether the agent is validated
     * @return stakeAmount The stake amount
     * @return expiryTimestamp The expiry timestamp
     */
    function getValidationDetails(address agent, address vault)
        external
        view
        returns (bool isValidated, uint256 stakeAmount, uint256 expiryTimestamp)
    {
        isValidated = _validations[agent][vault];
        stakeAmount = _validationStakes[agent][vault];
        expiryTimestamp = _validationExpiry[agent][vault];
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
     * @dev Set the validation token (only owner)
     * @param newValidationToken The address of the new validation token
     */
    function setValidationToken(address newValidationToken) external onlyOwner {
        require(newValidationToken != address(0), "ValidationRegistry: Invalid validation token address");
        require(newValidationToken != address(validationToken), "ValidationRegistry: Token must be different");

        address oldToken = address(validationToken);
        validationToken = IERC20(newValidationToken);

        emit ValidationTokenUpdated(oldToken, newValidationToken, block.timestamp);
    }

    /**
     * @dev Set the minimum stake amount (only owner)
     * @param newMinStakeAmount The new minimum stake amount
     */
    function setMinStakeAmount(uint256 newMinStakeAmount) external onlyOwner {
        require(newMinStakeAmount > 0, "ValidationRegistry: Min stake amount must be greater than zero");
        require(newMinStakeAmount != minStakeAmount, "ValidationRegistry: Amount must be different");

        uint256 oldAmount = minStakeAmount;
        minStakeAmount = newMinStakeAmount;

        emit MinStakeAmountUpdated(oldAmount, newMinStakeAmount, block.timestamp);
    }

    /**
     * @dev Set the validation expiry duration (only owner)
     * @param newValidationExpiryDuration The new validation expiry duration
     */
    function setValidationExpiryDuration(uint256 newValidationExpiryDuration) external onlyOwner {
        require(newValidationExpiryDuration > 0, "ValidationRegistry: Expiry duration must be greater than zero");
        require(
            newValidationExpiryDuration != validationExpiryDuration, "ValidationRegistry: Duration must be different"
        );

        uint256 oldDuration = validationExpiryDuration;
        validationExpiryDuration = newValidationExpiryDuration;

        emit ValidationExpiryDurationUpdated(oldDuration, newValidationExpiryDuration, block.timestamp);
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

    /**
     * @dev Get validation entries for a specific validator
     * @param validator The address of the validator
     * @return Array of ValidationEntry structs by the validator
     */
    function getValidationEntriesForValidator(address validator) external view returns (ValidationEntry[] memory) {
        uint256 count = 0;

        // Count matching entries
        for (uint256 i = 0; i < _validationEntries.length; i++) {
            if (_validationEntries[i].validator == validator) {
                count++;
            }
        }

        // Create result array
        ValidationEntry[] memory result = new ValidationEntry[](count);
        uint256 index = 0;

        // Populate result array
        for (uint256 i = 0; i < _validationEntries.length; i++) {
            if (_validationEntries[i].validator == validator) {
                result[index] = _validationEntries[i];
                index++;
            }
        }

        return result;
    }

    /**
     * @dev Get total staked amount in the contract
     * @return The total amount of validation tokens staked
     */
    function getTotalStakedAmount() external view returns (uint256) {
        return validationToken.balanceOf(address(this));
    }

    /**
     * @dev Get configuration parameters
     * @return validationTokenAddress The address of the validation token
     * @return minStake The minimum stake amount
     * @return expiryDuration The validation expiry duration
     */
    function getConfiguration()
        external
        view
        returns (address validationTokenAddress, uint256 minStake, uint256 expiryDuration)
    {
        validationTokenAddress = address(validationToken);
        minStake = minStakeAmount;
        expiryDuration = validationExpiryDuration;
    }
}
