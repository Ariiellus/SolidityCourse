// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {DeployBox} from "../script/DeployBox.s.sol";
import {UpgradeBox} from "../script/UpgradeBox.s.sol";
import {BoxV2} from "../src/BoxV2.sol";

contract DeployAndUpgradeTest is Test {
    DeployBox public deployer;
    UpgradeBox public upgrader;
    address public owner = makeAddr("owner");

    address public proxy;

    function setUp() public {
      deployer = new DeployBox();
      upgrader = new UpgradeBox();
      proxy = deployer.deployBox();         
    }

    function testProxyStartsAsBox1() public {
      vm.expectRevert();
      BoxV2(proxy).setNumber(7);
    }

    function testUpgrade() public {
      BoxV2 boxV2 = new BoxV2();
      proxy = upgrader.upgradeBox(proxy, address(boxV2));

      uint256 expectedValue = 2;
      assertEq(expectedValue, BoxV2(proxy).version());

      BoxV2(proxy).setNumber(expectedValue);
      assertEq(expectedValue, BoxV2(proxy).getNumber());
    }
}