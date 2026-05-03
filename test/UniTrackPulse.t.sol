// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/UniTrackPulse.sol";

contract UniTrackPulseTest is Test {
    UniTrackPulse pulse;
    address owner;
    address wallet1 = address(0x1111);
    address wallet2 = address(0x2222);
    address wallet3 = address(0x3333);
    address attacker = address(0xdead);

    function setUp() public {
        owner = address(this);
        pulse = new UniTrackPulse();
    }

    // ===== OWNERSHIP =====

    function test_ownerIsDeployer() public view {
        assertEq(pulse.owner(), owner);
    }

    function test_ownerIsImmutable() public view {
        // owner is immutable — no setter exists. Verified by type.
        assertEq(pulse.owner(), owner);
    }

    // ===== REGISTRATION =====

    function test_registerWallet() public {
        pulse.registerWallet(wallet1);
        assertTrue(pulse.registered(wallet1));
        assertEq(pulse.totalWallets(), 1);
    }

    function test_registerMultipleWallets() public {
        pulse.registerWallet(wallet1);
        pulse.registerWallet(wallet2);
        pulse.registerWallet(wallet3);
        assertEq(pulse.totalWallets(), 3);
    }

    function test_revertRegisterDuplicate() public {
        pulse.registerWallet(wallet1);
        vm.expectRevert("Already registered");
        pulse.registerWallet(wallet1); // should revert
    }

    function test_revertRegisterByNonOwner() public {
        vm.prank(attacker);
        vm.expectRevert("Not owner");
        pulse.registerWallet(wallet1);
    }

    function test_registerZeroAddress() public {
        // Known V1 finding: no zero-address guard
        pulse.registerWallet(address(0));
        assertTrue(pulse.registered(address(0)));
    }

    // ===== PULSE =====

    function test_pulse() public {
        pulse.registerWallet(wallet1);
        vm.prank(wallet1);
        pulse.pulse(keccak256("v1.0.0"));
        assertEq(pulse.pulseCount(wallet1), 1);
        assertEq(pulse.totalPulses(), 1);
        assertGt(pulse.lastPulse(wallet1), 0);
    }

    function test_multiplePulses() public {
        pulse.registerWallet(wallet1);
        vm.startPrank(wallet1);
        pulse.pulse(keccak256("v1.0.0"));
        pulse.pulse(keccak256("v1.0.0"));
        pulse.pulse(keccak256("v1.0.1"));
        vm.stopPrank();
        assertEq(pulse.pulseCount(wallet1), 3);
        assertEq(pulse.totalPulses(), 3);
    }

    function test_revertPulseUnregistered() public {
        vm.prank(attacker);
        vm.expectRevert("Not registered");
        pulse.pulse(keccak256("v1.0.0"));
    }

    function test_pulseEmitsEvent() public {
        pulse.registerWallet(wallet1);
        vm.prank(wallet1);
        vm.expectEmit(true, true, false, true);
        emit UniTrackPulse.PulseRecorded(wallet1, keccak256("v1.0.0"), block.timestamp, 1, 1);
        pulse.pulse(keccak256("v1.0.0"));
    }

    // ===== ROTATION =====

    function test_rotateWallet() public {
        pulse.registerWallet(wallet1);
        vm.prank(wallet1);
        pulse.pulse(keccak256("v1.0.0"));

        vm.prank(wallet1);
        pulse.rotateWallet(wallet2);

        assertFalse(pulse.registered(wallet1));
        assertTrue(pulse.registered(wallet2));
        assertEq(pulse.pulseCount(wallet2), 1); // carried over
    }

    function test_revertRotateUnregistered() public {
        vm.prank(attacker);
        vm.expectRevert("Not registered");
        pulse.rotateWallet(wallet2);
    }

    function test_revertRotateToRegistered() public {
        pulse.registerWallet(wallet1);
        pulse.registerWallet(wallet2);
        vm.prank(wallet1);
        vm.expectRevert("Already registered");
        pulse.rotateWallet(wallet2);
    }

    function test_rotateStaleState() public {
        // Known V2 finding: stale pulseCount/lastPulse not cleaned on old wallet
        pulse.registerWallet(wallet1);
        vm.prank(wallet1);
        pulse.pulse(keccak256("v1.0.0"));

        vm.prank(wallet1);
        pulse.rotateWallet(wallet2);

        // Old wallet still has stale data (not cleaned — informational finding)
        assertEq(pulse.pulseCount(wallet1), 1); // stale
        assertGt(pulse.lastPulse(wallet1), 0);  // stale
        assertFalse(pulse.registered(wallet1)); // but not registered
    }

    function test_totalWalletsNotDecremented() public {
        // Known V4 finding: totalWallets only increments
        pulse.registerWallet(wallet1);
        assertEq(pulse.totalWallets(), 1);

        vm.prank(wallet1);
        pulse.rotateWallet(wallet2);
        // totalWallets stays 1 — rotation doesn't change it
        assertEq(pulse.totalWallets(), 1);
    }

    // ===== FUZZ TESTS =====

    function testFuzz_registerAndPulse(address wallet, bytes32 hash) public {
        vm.assume(wallet != address(0)); // skip zero for cleaner fuzz
        vm.assume(!pulse.registered(wallet));
        pulse.registerWallet(wallet);
        vm.prank(wallet);
        pulse.pulse(hash);
        assertEq(pulse.pulseCount(wallet), 1);
    }

    function testFuzz_cannotPulseUnregistered(address wallet, bytes32 hash) public {
        vm.assume(!pulse.registered(wallet));
        vm.prank(wallet);
        vm.expectRevert("Not registered");
        pulse.pulse(hash);
    }

    function testFuzz_onlyOwnerRegisters(address caller, address wallet) public {
        vm.assume(caller != owner);
        vm.assume(!pulse.registered(wallet));
        vm.prank(caller);
        vm.expectRevert("Not owner");
        pulse.registerWallet(wallet);
    }

    function testFuzz_totalPulsesAlwaysIncrement(uint8 n) public {
        vm.assume(n > 0 && n < 50);
        pulse.registerWallet(wallet1);
        vm.startPrank(wallet1);
        for (uint8 i = 0; i < n; i++) {
            pulse.pulse(keccak256(abi.encodePacked(i)));
        }
        vm.stopPrank();
        assertEq(pulse.totalPulses(), n);
        assertEq(pulse.pulseCount(wallet1), n);
    }

    // ===== REENTRANCY PROOF =====

    function test_noExternalCalls() public {
        // This contract makes ZERO external calls (no .call, no .transfer, no .send)
        // Therefore reentrancy is architecturally impossible.
        // This test confirms basic flow doesn't revert unexpectedly.
        pulse.registerWallet(wallet1);
        vm.startPrank(wallet1);
        pulse.pulse(keccak256("a"));
        pulse.pulse(keccak256("b"));
        pulse.rotateWallet(wallet2);
        vm.stopPrank();
        vm.prank(wallet2);
        pulse.pulse(keccak256("c"));
        assertEq(pulse.totalPulses(), 3);
    }

    // ===== INVARIANT: no ETH trapping =====

    function test_cannotReceiveETH() public {
        vm.deal(attacker, 1 ether);
        vm.prank(attacker);
        (bool success,) = address(pulse).call{value: 1 ether}("");
        assertFalse(success); // no receive/fallback — ETH rejected
    }
}
