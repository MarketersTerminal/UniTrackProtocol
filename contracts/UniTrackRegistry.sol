// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title UniTrackRegistry
/// @notice Stores SHA-256 hash per vault version. Immutable. No proxy.
/// @dev Owner publishes version hashes. Anyone can read and verify.

contract UniTrackRegistry {
    address public immutable owner;

    struct Version {
        string versionId;
        bytes32 hash;
        uint256 timestamp;
    }

    mapping(string => Version) public versions;
    string[] public versionIds;

    event VersionPublished(string indexed versionId, bytes32 hash, uint256 timestamp);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function publishVersion(string calldata versionId, bytes32 hash) external onlyOwner {
        require(versions[versionId].timestamp == 0, "Version exists");
        versions[versionId] = Version(versionId, hash, block.timestamp);
        versionIds.push(versionId);
        emit VersionPublished(versionId, hash, block.timestamp);
    }

    function getVersion(string calldata versionId) external view returns (string memory, bytes32, uint256) {
        Version memory v = versions[versionId];
        return (v.versionId, v.hash, v.timestamp);
    }

    function totalVersions() external view returns (uint256) {
        return versionIds.length;
    }
}
