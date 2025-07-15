// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {BasicNFT} from "../src/BasicNFT.sol";
import {DeployBasicNFT} from "../script/DeployBasicNFT.s.sol";

contract TestBasicNFT is Test {
  DeployBasicNFT public deployer;
  BasicNFT public basicNFT;
  address public USER = makeAddr("user");
  string public constant SHIBA_URI = "ipfs://bafybeie5venjwpgkqpthezwtyrm7bqm5wzkiukcvqdyftd4behdamkw3re.ipfs.dweb.link?filename=shiba-inu.png";

  function setUp() public {
    deployer = new DeployBasicNFT();
    basicNFT = deployer.run();
  }

  function testNameIsCorrect() public view {
    string memory expectedName = "BasicNFT";
    string memory actualName = basicNFT.name();

    assertEq(
      keccak256(abi.encodePacked(expectedName)), keccak256(abi.encodePacked(actualName))
    );
  }

  function testCanMintAndHaveBalance() public {
    vm.prank(USER);
    basicNFT.mint(SHIBA_URI);

    assertEq(basicNFT.balanceOf(USER), 1);
    assertEq(basicNFT.ownerOf(0), USER);
    assertEq(keccak256(abi.encodePacked(basicNFT.tokenURI(0))), keccak256(abi.encodePacked(SHIBA_URI)));
  }
}