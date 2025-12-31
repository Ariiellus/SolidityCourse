// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Script, console2} from "@forge-std/Script.sol";
import {EntryPoint} from "lib/account-abstraction/contracts/core/EntryPoint.sol";

contract HelperConfig is Script {
    function run() public {}

    struct NetworkConfig {
        address entryPoint;
        address account;
    }

    uint256 constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant LOCAL_CHAIN_ID = 31337;
    address constant BURNER_WALLET = 0x6E89B5168A0a3373D87559C5d1D279b3c89b6104;
    address constant ANVIL_DEFAULT_WALLET = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    NetworkConfig public localNetworkConfig;

    function getConfig() public returns (NetworkConfig memory) {
        if (block.chainid == SEPOLIA_CHAIN_ID) {
            return getSepoliaConfig();
        } else {
            return getOrCreateAnvilConfig();
        }
    }

    function getSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({entryPoint: address(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789), account: BURNER_WALLET});
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.entryPoint != address(0)) {
            return localNetworkConfig;
        }

        // Deploy EntryPoint for local testing
        console2.log("Deploying EntryPoint for local testing");
        vm.startBroadcast(ANVIL_DEFAULT_WALLET);
        EntryPoint entryPoint = new EntryPoint();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({entryPoint: address(entryPoint), account: ANVIL_DEFAULT_WALLET});

        return localNetworkConfig;
    }
}
