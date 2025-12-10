// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;
    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() public {
        vm.startPrank(owner);
        vm.deal(owner, 10 ether);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        (bool success, ) = payable(address(vault)).call{value: 1e18}("");
        require(success, "Vault deposit failed");
        vm.stopPrank();
    }

    function test_depositLinear(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();

        // check our rebase token balance
        uint256 startBalance = rebaseToken.balanceOf(user);
        assertEq(startBalance, amount);

        // warp the time and check the balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebaseToken.balanceOf(user);
        assertGt(middleBalance, startBalance);

        // warp the time again by the same amount and check the balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseToken.balanceOf(user);
        assertGt(endBalance, middleBalance);

        assertApproxEqAbs(
            endBalance - middleBalance,
            middleBalance - startBalance,
            1
        );

        vm.stopPrank();
    }

    function test_RedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();

        // check our rebase token balance
        uint256 startBalance = rebaseToken.balanceOf(user);
        assertEq(startBalance, amount);

        // redeem the tokens
        vault.withdraw(amount);

        // check our rebase token balance
        uint256 endBalance = rebaseToken.balanceOf(user);
        assertEq(endBalance, 0);
    }
}
