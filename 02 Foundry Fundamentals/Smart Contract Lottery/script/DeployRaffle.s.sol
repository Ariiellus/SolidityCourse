// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CreateSubscription} from "./Interactions.s.sol";

contract DeployRaffle is Script {
  function run() public {
  }

  function deployContract() public returns (Raffle, HelperConfig) {
    HelperConfig helperConfig = new HelperConfig();
    HelperConfig.NetworkConfig memory config = helperConfig.getConfigByChainId(block.chainid);

    if (config.subscriptionId == 0) {
      CreateSubscription subscriptionContract = new CreateSubscription();
      (config.subscriptionId, config.vrfCoordinator) = subscriptionContract.createSubscription(config.vrfCoordinator);
    }

    vm.startBroadcast();
      Raffle raffle = new Raffle(
        config.entranceFee,
        config.interval,
        config.vrfCoordinator,
        config.gasLane,
        config.subscriptionId,
        config.callbackGasLimit
      );
    vm.stopBroadcast();

    return (raffle, helperConfig);
  }
}