// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/UniTrackRegistry.sol";

contract UniTrackRegistryTest is Test {
    UniTrackRegistry registry;
    address owner;
    address attacker = address(0xdead);

    function setUp() public {
        owner = address(this);
        registry = new UniTrackRegistry();
    }

    function test_ownerIsDeployer() public view {
        assertEq(registry.owner(), owner);
    }

    function test_publishVersion() public {
        bytes32 hash = keccak256("vault-v1.0.0-contents");
        registry.publishVersion("v1.0.0", hash);
        (string memory vid, bytes32 h, uint256 ts) = registry.versions("v1.0.0");
        assertEq(h, hash);
        assertGt(ts, 0);
    }

    function test_revertPublishDuplicate() public {
        bytes32 hash = keccak256("vault-v1.0.0");
        registry.publishVersion("v1.0.0", hash);
        vm.expectRevert("Version exists");
        registry.publishVersion("v1.0.0", keccak256("different"));
    }

    function test_revertPublishByNonOwner() public {
        vm.prank(attacker);
        vm.expectRevert("Not owner");
        registry.publishVersion("v1.0.0", keccak256("hack"));
    }

    function test_totalVersionsIncrements() public {
        registry.publishVersion("v1.0.0", keccak256("a"));
        registry.publishVersion("v1.0.1", keccak256("b"));
        assertEq(registry.totalVersions(), 2);
    }

    function test_versionIdsArray() public {
        registry.publishVersion("v1.0.0", keccak256("a"));
        assertEq(registry.versionIds(0), "v1.0.0");
    }

    function test_cannotReceiveETH() public {
        vm.deal(attacker, 1 ether);
        vm.prank(attacker);
        (bool success,) = address(registry).call{value: 1 ether}("");
        assertFalse(success);
    }

    function testFuzz_onlyOwnerPublishes(address caller) public {
        vm.assume(caller != owner);
        vm.prank(caller);
        vm.expectRevert("Not owner");
        registry.publishVersion("vX", keccak256("x"));
    }

    function testFuzz_publishAndRetrieve(string calldata vid, bytes32 hash) public {
        vm.assume(bytes(vid).length > 0 && bytes(vid).length < 100);
        registry.publishVersion(vid, hash);
        (, bytes32 stored,) = registry.versions(vid);
        assertEq(stored, hash);
    }
}
