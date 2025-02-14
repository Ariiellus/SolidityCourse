// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../src/FundMe.sol";
import {DeployFundMe} from "../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
  FundMe fundMe;

  function setUp() external {
    // fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
    DeployFundMe deployFundMe = new DeployFundMe();
    fundMe = deployFundMe.run();
  }

  function testMinDollarIsFive() public view {
    assertEq(fundMe.MINIMUM_USD(), 5e18);
  }

  function testOwnerIsMsgSender() public view {
    assertEq(fundMe.i_owner(), msg.sender);
  }

  function testPriceFeed() public view {
    uint256 version = fundMe.getVersion();
    // 4 for sepolia, 6 for mainnet
    // how to get version automatically?
    // update: factoring increase lines of code
    assertEq(version, 4);
  }
}