// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AgentWall} from "../contracts/AgentWall.sol";
import {MockAgentId} from "../contracts/MockAgentId.sol";

/// @dev Minimal cheatcode interface (subset of Foundry's Vm) so the test
///      suite needs no external dependencies.
interface Vm {
    function warp(uint256 newTimestamp) external;
    function prank(address msgSender) external;
    function expectRevert() external;
    function expectRevert(bytes calldata revertData) external;
    function expectEmit(bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData) external;
}

/// @dev Tiny assertion helpers (stand-in for forge-std's Test).
contract TestLite {
    Vm internal constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function assertEq(uint256 a, uint256 b, string memory what) internal pure {
        require(a == b, string.concat("assertEq failed: ", what));
    }

    function assertEq(address a, address b, string memory what) internal pure {
        require(a == b, string.concat("assertEq failed: ", what));
    }

    function assertEq(string memory a, string memory b, string memory what) internal pure {
        require(keccak256(bytes(a)) == keccak256(bytes(b)), string.concat("assertEq failed: ", what));
    }

    function assertTrue(bool cond, string memory what) internal pure {
        require(cond, string.concat("assertTrue failed: ", what));
    }

    function assertFalse(bool cond, string memory what) internal pure {
        require(!cond, string.concat("assertFalse failed: ", what));
    }
}

contract AgentWallTest is TestLite {
    MockAgentId internal registry;
    AgentWall internal wall;

    address internal holder = address(0xA11CE);
    address internal holder2 = address(0xB0B);
    address internal stranger = address(0xBAD);

    event Signed(address indexed signer, uint256 indexed index, string message, uint256 timestamp);

    function setUp() public {
        registry = new MockAgentId();
        wall = new AgentWall(address(registry));
        registry.setBalance(holder, 1);
        registry.setBalance(holder2, 2);
        // stranger keeps balance 0
        vm.warp(1_700_000_000);
    }

    function test_HasAgentId() public view {
        assertTrue(wall.hasAgentId(holder), "holder has Agent ID");
        assertTrue(wall.hasAgentId(holder2), "holder2 has Agent ID");
        assertFalse(wall.hasAgentId(stranger), "stranger has no Agent ID");
    }

    function test_HolderCanSign() public {
        vm.prank(holder);
        wall.sign("Hello AgentWall!");

        assertEq(wall.totalSigns(), 1, "one sign stored");
        AgentWall.Sign memory s = wall.getSign(0);
        assertEq(s.signer, holder, "signer recorded");
        assertEq(s.message, "Hello AgentWall!", "message recorded");
        assertEq(s.timestamp, 1_700_000_000, "timestamp recorded");
        assertEq(wall.lastSignAt(holder), 1_700_000_000, "lastSignAt set");
    }

    function test_SignEmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit Signed(holder, 0, "event check", 1_700_000_000);
        vm.prank(holder);
        wall.sign("event check");
    }

    function test_NonHolderReverts() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(AgentWall.NotAgentIdHolder.selector, stranger));
        wall.sign("I should not be able to sign");
        assertEq(wall.totalSigns(), 0, "nothing stored");
    }

    function test_EmptyMessageReverts() public {
        vm.prank(holder);
        vm.expectRevert(abi.encodeWithSelector(AgentWall.EmptyMessage.selector));
        wall.sign("");
    }

    function test_OverlongMessageReverts() public {
        // 281 bytes > 280 cap
        string memory long = new string(281);
        bytes memory b = bytes(long);
        for (uint256 i = 0; i < b.length; i++) b[i] = "a";
        vm.prank(holder);
        vm.expectRevert(abi.encodeWithSelector(AgentWall.MessageTooLong.selector, 281));
        wall.sign(string(b));
    }

    function test_ExactlyMaxMessageOk() public {
        string memory maxMsg = new string(280);
        bytes memory b = bytes(maxMsg);
        for (uint256 i = 0; i < b.length; i++) b[i] = "b";
        vm.prank(holder);
        wall.sign(string(b));
        assertEq(wall.totalSigns(), 1, "280-byte message accepted");
    }

    function test_CooldownEnforced() public {
        vm.prank(holder);
        wall.sign("first");

        // Immediate second sign reverts
        vm.prank(holder);
        vm.expectRevert(abi.encodeWithSelector(AgentWall.CooldownActive.selector, 1_700_000_000 + 24 hours));
        wall.sign("too soon");

        // 23h59m later: still reverts
        vm.warp(1_700_000_000 + 24 hours - 1);
        vm.prank(holder);
        vm.expectRevert(abi.encodeWithSelector(AgentWall.CooldownActive.selector, 1_700_000_000 + 24 hours));
        wall.sign("still too soon");

        // Exactly 24h later: allowed again
        vm.warp(1_700_000_000 + 24 hours);
        vm.prank(holder);
        wall.sign("second, a day later");
        assertEq(wall.totalSigns(), 2, "second sign after cooldown stored");
    }

    function test_CooldownIsPerAddress() public {
        vm.prank(holder);
        wall.sign("holder signs");
        // A different holder is not affected by holder's cooldown
        vm.prank(holder2);
        wall.sign("holder2 signs right after");
        assertEq(wall.totalSigns(), 2, "both signs stored");
    }

    function test_Pagination() public {
        // Three signs from three different moments/addresses
        vm.prank(holder);
        wall.sign("one");
        vm.prank(holder2);
        wall.sign("two");
        vm.warp(1_700_000_000 + 24 hours);
        vm.prank(holder);
        wall.sign("three");

        AgentWall.Sign[] memory all = wall.getSigns(0, 100);
        assertEq(all.length, 3, "page returns all 3");
        assertEq(all[0].message, "one", "order preserved [0]");
        assertEq(all[1].message, "two", "order preserved [1]");
        assertEq(all[2].message, "three", "order preserved [2]");

        AgentWall.Sign[] memory firstTwo = wall.getSigns(0, 2);
        assertEq(firstTwo.length, 2, "limit respected");

        AgentWall.Sign[] memory tail = wall.getSigns(2, 100);
        assertEq(tail.length, 1, "offset tail length");
        assertEq(tail[0].message, "three", "offset tail content");

        AgentWall.Sign[] memory beyond = wall.getSigns(99, 10);
        assertEq(beyond.length, 0, "offset beyond end is empty");
    }
}
