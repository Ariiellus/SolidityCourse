// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {BasicNFT} from "../src/BasicNFT.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract MintBasicNFT is Script {
  function run() external {
    address mostRecentDeployed = DevOpsTools.get_most_recent_deployment(
      "BasicNFT",
      block.chainid
    );
    mintNFTOnContract(mostRecentDeployed);
  }

  function mintNFTOnContract(address contractAddress) public {
    vm.startBroadcast();
    BasicNFT(contractAddress).mint("ipfs://QmSJTSWaVgHFKmWCJWFVGjFBCYs5SZ4zPxHGvTfgH8PsT7");
    vm.stopBroadcast();
  }
}