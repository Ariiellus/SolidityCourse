// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.5.0
pragma solidity ^0.8.33;

import {Test} from "@forge-std/Test.sol";
import {MyGovernor} from "../src/Governor.sol";
import {GovToken} from "../src/GovToken.sol";
import {Timelock} from "../src/Timelock.sol";
import {Box} from "../src/Box.sol";
import {console} from "forge-std/console.sol";

contract GovernorTest is Test {
    MyGovernor public governor;
    GovToken public govToken;
    Timelock public timelock;
    Box public box;

    address public user = makeAddr("user");
    uint256 public constant INITIAL_SUPPLY = 100 ether;

    address[] public proposers = [user];
    address[] public executors = [user];

    uint256 public constant MIN_DELAY = 3600; // 1 hour
    uint256 public constant QUORUM_PERCENTAGE = 4; // 4%
    uint256 public constant VOTING_DELAY = 7200; // 1 day in blocks
    uint256 public constant VOTING_PERIOD = 50400; // 1 week in blocks

    function setUp() public {
        govToken = new GovToken();
        govToken.mint(user, INITIAL_SUPPLY);

        vm.startPrank(user);
        govToken.delegate(user);
        timelock = new Timelock(MIN_DELAY, proposers, executors);

        governor = new MyGovernor(govToken, timelock);

        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();

        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(governor));
        timelock.revokeRole(adminRole, address(this));
        vm.stopPrank();

        box = new Box();
        box.transferOwnership(address(timelock));
    }

    function testCantUpdateBoxWithoutGovernance() public {
        vm.expectRevert();
        box.store(1);
    }

    function testCanUpdateBoxWithGovernance() public {
        uint256 valueToStore = 12423;
        string memory description = "Store 12423 in the box";
        bytes memory encodedParams = abi.encodeWithSignature("store(uint256)", valueToStore);

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        values[0] = 0;
        calldatas[0] = encodedParams;
        targets[0] = address(box);

        uint256 proposalId = governor.propose(targets, values, calldatas, description);
        console.log("Proposal State:", uint256(governor.state(proposalId)));

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        console.log("Proposal State:", uint256(governor.state(proposalId)));

        string memory reason = "I like this proposal";
        uint8 voteWay = 1; // 1 = For
        vm.prank(user);
        governor.castVoteWithReason(proposalId, voteWay, reason);

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        governor.queue(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + 1);

        governor.execute(targets, values, calldatas, descriptionHash);
        assertEq(box.getNumber(), valueToStore);
    }
}
