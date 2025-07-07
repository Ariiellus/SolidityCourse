// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script {
  function run() public {
    deployContract();
  }

  function deployContract() public returns (Raffle, HelperConfig) {
    HelperConfig helperConfig = new HelperConfig();
    HelperConfig.NetworkConfig memory config = helperConfig.getConfigByChainId(block.chainid);

    if (config.subscriptionId == 0) {
      CreateSubscription subscriptionContract = new CreateSubscription();
      subscriptionContract.createSubscription(config.vrfCoordinator, config.account);
      
      // Get the most recent subscription ID from the VRF coordinator
      // This is more reliable than using the return value from simulation
      config.subscriptionId = subscriptionContract.getLatestSubscriptionId(config.vrfCoordinator);

      FundSubscription fundSubscription = new FundSubscription();
      fundSubscription.fundSubscription(config.vrfCoordinator, config.subscriptionId, config.link, config.account);
    }

    vm.startBroadcast(config.account);
      Raffle raffle = new Raffle(
        config.entranceFee,
        config.interval,
        config.vrfCoordinator,
        config.gasLane,
        config.subscriptionId,
        config.callbackGasLimit
      );
    vm.stopBroadcast();

    AddConsumer addConsumer = new AddConsumer();
    addConsumer.addConsumer(config.vrfCoordinator, config.subscriptionId, address(raffle), config.account);

    return (raffle, helperConfig);
  }
}