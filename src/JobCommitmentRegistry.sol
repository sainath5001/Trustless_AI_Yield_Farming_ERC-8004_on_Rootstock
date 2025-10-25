// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title JobCommitmentRegistry
 * @dev Registry for tracking AI job commitments and validator attestations
 * @notice This contract links off-chain AI actions to on-chain records for verifiability
 */
contract JobCommitmentRegistry is Ownable {
    // Job commitment structure
    struct JobCommitment {
        bytes32 jobHash; // Hash of the job parameters
        address agent; // Agent performing the job
        address vault; // Vault the job relates to
        uint256 timestamp; // When the commitment was made
        bool isCompleted; // Whether the job has been completed
        bytes32 resultHash; // Hash of the job result (if completed)
        uint256 completionTime; // When the job was completed
    }

    // Validator attestation structure
    struct ValidatorAttestation {
        address validator; // Address of the validator
        bytes32 jobHash; // Job hash being attested to
        bool isValid; // Whether the validator attests the job is valid
        string reason; // Reason for the attestation
        uint256 timestamp; // When the attestation was made
    }

    // Mapping from job hash to JobCommitment
    mapping(bytes32 => JobCommitment) public jobCommitments;

    // Mapping from job hash to array of validator attestations
    mapping(bytes32 => ValidatorAttestation[]) public jobAttestations;

    // Array of all job hashes for enumeration
    bytes32[] public allJobHashes;

    // Mapping to track if a job hash exists
    mapping(bytes32 => bool) public jobExists;

    // Events
    event JobCommitted(bytes32 indexed jobHash, address indexed agent, address indexed vault, uint256 timestamp);
    event JobCompleted(bytes32 indexed jobHash, bytes32 resultHash, uint256 completionTime);
    event JobAttested(
        bytes32 indexed jobHash, address indexed validator, bool isValid, string reason, uint256 timestamp
    );

    // Modifiers
    modifier onlyValidatedAgent(address agent, address vault) {
        // This would typically check against ValidationRegistry
        // For now, we'll allow any agent to commit jobs
        _;
    }

    modifier onlyExistingJob(bytes32 jobHash) {
        require(jobExists[jobHash], "JobCommitmentRegistry: Job does not exist");
        _;
    }

    /**
     * @dev Constructor
     */
    constructor() Ownable(msg.sender) {
        // Owner is automatically set by Ownable constructor
    }

    /**
     * @dev Commit to performing an AI job
     * @param jobHash Hash of the job parameters
     * @param agent Address of the agent performing the job
     * @param vault Address of the vault the job relates to
     */
    function commitJob(bytes32 jobHash, address agent, address vault) external onlyValidatedAgent(agent, vault) {
        require(jobHash != bytes32(0), "JobCommitmentRegistry: Invalid job hash");
        require(agent != address(0), "JobCommitmentRegistry: Invalid agent address");
        require(vault != address(0), "JobCommitmentRegistry: Invalid vault address");
        require(!jobExists[jobHash], "JobCommitmentRegistry: Job already exists");

        JobCommitment memory commitment = JobCommitment({
            jobHash: jobHash,
            agent: agent,
            vault: vault,
            timestamp: block.timestamp,
            isCompleted: false,
            resultHash: bytes32(0),
            completionTime: 0
        });

        jobCommitments[jobHash] = commitment;
        allJobHashes.push(jobHash);
        jobExists[jobHash] = true;

        emit JobCommitted(jobHash, agent, vault, block.timestamp);
    }

    /**
     * @dev Complete a job and provide result hash
     * @param jobHash Hash of the job
     * @param resultHash Hash of the job result
     */
    function completeJob(bytes32 jobHash, bytes32 resultHash) external onlyExistingJob(jobHash) {
        JobCommitment storage commitment = jobCommitments[jobHash];

        require(msg.sender == commitment.agent, "JobCommitmentRegistry: Only the agent can complete the job");
        require(!commitment.isCompleted, "JobCommitmentRegistry: Job already completed");
        require(resultHash != bytes32(0), "JobCommitmentRegistry: Invalid result hash");

        commitment.isCompleted = true;
        commitment.resultHash = resultHash;
        commitment.completionTime = block.timestamp;

        emit JobCompleted(jobHash, resultHash, block.timestamp);
    }

    /**
     * @dev Attest to the validity of a job (anyone can attest)
     * @param jobHash Hash of the job
     * @param isValid Whether the validator attests the job is valid
     * @param reason Reason for the attestation
     */
    function attestJob(bytes32 jobHash, bool isValid, string calldata reason) external onlyExistingJob(jobHash) {
        require(bytes(reason).length > 0, "JobCommitmentRegistry: Reason cannot be empty");

        ValidatorAttestation memory attestation = ValidatorAttestation({
            validator: msg.sender,
            jobHash: jobHash,
            isValid: isValid,
            reason: reason,
            timestamp: block.timestamp
        });

        jobAttestations[jobHash].push(attestation);

        emit JobAttested(jobHash, msg.sender, isValid, reason, block.timestamp);
    }

    /**
     * @dev Get job commitment details
     * @param jobHash Hash of the job
     * @return The JobCommitment struct
     */
    function getJobCommitment(bytes32 jobHash) external view returns (JobCommitment memory) {
        require(jobExists[jobHash], "JobCommitmentRegistry: Job does not exist");
        return jobCommitments[jobHash];
    }

    /**
     * @dev Get all attestations for a job
     * @param jobHash Hash of the job
     * @return Array of ValidatorAttestation structs
     */
    function getJobAttestations(bytes32 jobHash) external view returns (ValidatorAttestation[] memory) {
        require(jobExists[jobHash], "JobCommitmentRegistry: Job does not exist");
        return jobAttestations[jobHash];
    }

    /**
     * @dev Get total number of jobs
     * @return The number of jobs
     */
    function getTotalJobs() external view returns (uint256) {
        return allJobHashes.length;
    }

    /**
     * @dev Get all job hashes
     * @return Array of all job hashes
     */
    function getAllJobHashes() external view returns (bytes32[] memory) {
        return allJobHashes;
    }

    /**
     * @dev Get jobs by agent
     * @param agent Address of the agent
     * @return Array of job hashes for the agent
     */
    function getJobsByAgent(address agent) external view returns (bytes32[] memory) {
        uint256 count = 0;

        // Count matching jobs
        for (uint256 i = 0; i < allJobHashes.length; i++) {
            if (jobCommitments[allJobHashes[i]].agent == agent) {
                count++;
            }
        }

        // Create result array
        bytes32[] memory result = new bytes32[](count);
        uint256 index = 0;

        // Populate result array
        for (uint256 i = 0; i < allJobHashes.length; i++) {
            if (jobCommitments[allJobHashes[i]].agent == agent) {
                result[index] = allJobHashes[i];
                index++;
            }
        }

        return result;
    }

    /**
     * @dev Get jobs by vault
     * @param vault Address of the vault
     * @return Array of job hashes for the vault
     */
    function getJobsByVault(address vault) external view returns (bytes32[] memory) {
        uint256 count = 0;

        // Count matching jobs
        for (uint256 i = 0; i < allJobHashes.length; i++) {
            if (jobCommitments[allJobHashes[i]].vault == vault) {
                count++;
            }
        }

        // Create result array
        bytes32[] memory result = new bytes32[](count);
        uint256 index = 0;

        // Populate result array
        for (uint256 i = 0; i < allJobHashes.length; i++) {
            if (jobCommitments[allJobHashes[i]].vault == vault) {
                result[index] = allJobHashes[i];
                index++;
            }
        }

        return result;
    }

    /**
     * @dev Get job statistics
     * @param jobHash Hash of the job
     * @return totalAttestations Total number of attestations
     * @return validAttestations Number of valid attestations
     * @return invalidAttestations Number of invalid attestations
     */
    function getJobStatistics(bytes32 jobHash)
        external
        view
        returns (uint256 totalAttestations, uint256 validAttestations, uint256 invalidAttestations)
    {
        require(jobExists[jobHash], "JobCommitmentRegistry: Job does not exist");

        ValidatorAttestation[] memory attestations = jobAttestations[jobHash];
        totalAttestations = attestations.length;

        for (uint256 i = 0; i < attestations.length; i++) {
            if (attestations[i].isValid) {
                validAttestations++;
            } else {
                invalidAttestations++;
            }
        }
    }
}
