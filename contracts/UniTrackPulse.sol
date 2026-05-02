// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title UniTrackPulse
/// @notice Records execution pulses on Base. Immutable. No proxy.
/// @dev Owner registers wallets at sale. Registered wallets pulse with a vault hash.
/// @dev No unbounded array — counters + events. Pulse history queryable via PulseRecorded event filter.
contract UniTrackPulse {
    address public immutable owner;

    mapping(address => bool) public registered;
    mapping(address => uint256) public pulseCount;
    mapping(address => uint256) public lastPulse;
    uint256 public totalPulses;
    uint256 public totalWallets;

    event WalletRegistered(address indexed wallet);
    event WalletRotated(address indexed oldWallet, address indexed newWallet);
    event PulseRecorded(
        address indexed wallet,
        bytes32 indexed versionHash,
        uint256 timestamp,
        uint256 walletTotal,
        uint256 globalTotal
    );

    modifier onlyOwner() { require(msg.sender == owner, "Not owner"); _; }

    constructor() { owner = msg.sender; }

    function registerWallet(address wallet) external onlyOwner {
        require(!registered[wallet], "Already registered");
        registered[wallet] = true;
        totalWallets++;
        emit WalletRegistered(wallet);
    }

    function rotateWallet(address newWallet) external {
        require(registered[msg.sender], "Not registered");
        require(!registered[newWallet], "Already registered");
        registered[msg.sender] = false;
        registered[newWallet] = true;
        pulseCount[newWallet] = pulseCount[msg.sender];
        lastPulse[newWallet] = lastPulse[msg.sender];
        emit WalletRotated(msg.sender, newWallet);
    }

    function pulse(bytes32 versionHash) external {
        require(registered[msg.sender], "Not registered");
        pulseCount[msg.sender]++;
        lastPulse[msg.sender] = block.timestamp;
        totalPulses++;
        emit PulseRecorded(msg.sender, versionHash, block.timestamp, pulseCount[msg.sender], totalPulses);
    }
}
