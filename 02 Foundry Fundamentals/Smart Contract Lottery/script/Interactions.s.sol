//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig, CodeConstants} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

contract CreateSubscription is Script {
  function createSubscriptionUsingConfig() public returns (uint256, address) {
    HelperConfig helperConfig = new HelperConfig();
    address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
    (uint256 subId,) =createSubscription(vrfCoordinator);
    return (subId, vrfCoordinator);
  }

  function createSubscription(address vrfCoordinator) public returns (uint256, address) {
    console2.log("Creating subscription on chainId: ", block.chainid);
    vm.startBroadcast();
    uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
    console2.log("Your subscription ID is: ", subId);
    vm.stopBroadcast();
    return (subId, vrfCoordinator);
  }

  function run() public {

  }
}

contract FundSubscription is Script, CodeConstants {
  uint256 public constant FUND_AMOUNT = 3 ether; // or 3 LINK

  function fundSubscriptionUsingConfig() public {
    HelperConfig helperConfig = new HelperConfig();
    address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
    uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
    address linkToken = helperConfig.getConfig().link;
    fundSubscription(vrfCoordinator, subscriptionId, linkToken);
    console2.log("Subscription funded!");
  }

  function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address linkToken) public {
    console2.log("Funding subscription: ", subscriptionId);
    console2.log("Using vrfCoordinator: ", vrfCoordinator);
    console2.log("Using link: ", linkToken);

    if (block.chainid == ANVIL_CHAIN_ID) {
      vm.startBroadcast();
      VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT);
      vm.stopBroadcast();
    } else {
      vm.startBroadcast();
      LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
      vm.stopBroadcast();
    }

  }
  function run() public {}
}



