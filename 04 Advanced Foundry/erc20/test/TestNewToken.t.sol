// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {DeployNewToken} from "../script/DeployNewToken.s.sol";
import {Test} from "forge-std/Test.sol";
import {NewToken} from "../src/NewToken.sol";
import {console2} from "forge-std/console2.sol";

contract TestNewToken is Test {
    NewToken public newToken;
    DeployNewToken public deployer;
    
    // Create two addresses for testing
		address public Alice = makeAddr("Alice");
		address public Bob = makeAddr("Bob");

    function setUp() public {
        deployer = new DeployNewToken();
        newToken = deployer.run();
        
        // Give some tokens to Alice and Bob for testing
        vm.prank(address(msg.sender));
        newToken.transfer(Alice, 20e18);
        vm.prank(address(msg.sender));
        newToken.transfer(Bob, 20e18);
    }

    function testNewTokenDeployment() public {
			// Making test transactions
			vm.prank(address(msg.sender));
			newToken.transfer(Alice, 15e18);
			vm.prank(Alice);
			newToken.transfer(Bob, 10e18);
			vm.prank(Bob);
			newToken.transfer(Alice, 5e18);

      // Check balances sum 100e18
      assertEq(newToken.balanceOf(address(msg.sender)) + newToken.balanceOf(Alice) + newToken.balanceOf(Bob), 100e18);

			console2.log("Deployer balance:", newToken.balanceOf(address(msg.sender)));
			console2.log("Alice balance:", newToken.balanceOf(Alice));
			console2.log("Bob balance:", newToken.balanceOf(Bob));
    }
      
    // Testing transferFrom
    function testAllowance() public {
      uint256 amountAllowed = 20e18;
      uint256 amountTransferred = 10e18;

      vm.prank(Alice);
      newToken.approve(Bob, amountAllowed); // Authorize Bob to spend 10 tokens in behalf of Alice

      vm.prank(Bob);
      newToken.transferFrom(Alice, Bob, amountTransferred);
      console2.log("Bob has transferred ", amountTransferred, " tokens from Alice");
      console2.log("Alice balance:", newToken.balanceOf(Alice));

      assertEq(newToken.balanceOf(Alice), amountTransferred);
    }
    
    // No need to create more test. When forge coverage:
    // ╭-----------------------------+---------------+---------------+---------------+---------------╮
    // | File                        | % Lines       | % Statements  | % Branches    | % Funcs       |
    // +=============================================================================================+
    // | script/DeployNewToken.s.sol | 100.00% (5/5) | 100.00% (5/5) | 100.00% (0/0) | 100.00% (1/1) |
    // |-----------------------------+---------------+---------------+---------------+---------------|
    // | src/NewToken.sol            | 100.00% (2/2) | 100.00% (1/1) | 100.00% (0/0) | 100.00% (1/1) |
    // |-----------------------------+---------------+---------------+---------------+---------------|
    // | Total                       | 100.00% (7/7) | 100.00% (6/6) | 100.00% (0/0) | 100.00% (2/2) |
    // ╰-----------------------------+---------------+---------------+---------------+---------------╯
}
