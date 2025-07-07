//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig, CodeConstants} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {IVRFSubscriptionV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFSubscriptionV2Plus.sol";

contract CreateSubscription is Script {
  function createSubscriptionUsingConfig() public returns (uint256, address) {
    HelperConfig helperConfig = new HelperConfig();
    address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
    address account = helperConfig.getConfig().account;
    (uint256 subId,) = createSubscription(vrfCoordinator, account);
    return (subId, vrfCoordinator);
  }

  function createSubscription(address vrfCoordinator, address account) public returns (uint256, address) {
    console2.log("Creating subscription on chainId: ", block.chainid);
    vm.startBroadcast(account);
    uint256 subId;
    
    if (block.chainid == 31337) {
      // Use Mock for local development
      subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
    } else {
      // Use actual interface for live testnets
      subId = IVRFCoordinatorV2Plus(vrfCoordinator).createSubscription();
    }
    
    vm.stopBroadcast();
    console2.log("Your subscription ID is: ", subId);
    return (subId, vrfCoordinator);
  }

  function getLatestSubscriptionId(address vrfCoordinator) public view returns (uint256) {
    // Get all subscription IDs and return the latest one for the caller
    uint256[] memory subscriptionIds = IVRFSubscriptionV2Plus(vrfCoordinator).getActiveSubscriptionIds(0, 0);
    
    // Find the most recent subscription owned by tx.origin (the deployer)
    for (uint256 i = subscriptionIds.length; i > 0; i--) {
      uint256 subId = subscriptionIds[i - 1];
      (,, ,address owner,) = IVRFSubscriptionV2Plus(vrfCoordinator).getSubscription(subId);
      if (owner == tx.origin) {
        return subId;
      }
    }
    
    revert("No subscription found for caller");
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
    address account = helperConfig.getConfig().account;
    fundSubscription(vrfCoordinator, subscriptionId, linkToken, account);
    console2.log("Subscription funded!");
  }

  function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address linkToken, address account) public {
    console2.log("Funding subscription: ", subscriptionId);
    console2.log("Using vrfCoordinator: ", vrfCoordinator);
    console2.log("Using link: ", linkToken);

    if (block.chainid == ANVIL_CHAIN_ID) {
      vm.startBroadcast();
      VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT);
      vm.stopBroadcast();
    } else {
      vm.startBroadcast(account);
      LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
      vm.stopBroadcast();
    }

  }
  function run() public {
    fundSubscriptionUsingConfig();
  }
}

contract AddConsumer is Script, CodeConstants {

  function addConsumerUsingConfig(address mostRecentlyDeployed) public {
    HelperConfig helperConfig = new HelperConfig();
    uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
    address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
    address account = helperConfig.getConfig().account;
    addConsumer(vrfCoordinator, subscriptionId, mostRecentlyDeployed, account);


  }
  function addConsumer(address vrfCoordinator, uint256 subscriptionId, address contractToAdd, address account) public {

    vm.startBroadcast(account);
    
    if (block.chainid == ANVIL_CHAIN_ID) {
      // Use Mock for local development
      VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subscriptionId, contractToAdd);
    } else {
      // Use actual interface for live testnets
      IVRFCoordinatorV2Plus(vrfCoordinator).addConsumer(subscriptionId, contractToAdd);
    }
    
    vm.stopBroadcast();
    console2.log("Consumer added!");

  }
 
  function run() public {
    address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
    addConsumerUsingConfig(mostRecentlyDeployed);
  }
}


