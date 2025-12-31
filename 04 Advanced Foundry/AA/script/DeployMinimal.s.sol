// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Script} from "@forge-std/Script.sol";
import {MinimalAccount} from "src/MinimalAccount.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployMinimal is Script {
    function run() public {
        (HelperConfig helperConfig, MinimalAccount minimalAccount) = deployMinimalAccount();
    }

    function deployMinimalAccount() public returns (HelperConfig, MinimalAccount) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();

        vm.startBroadcast(networkConfig.account);
        MinimalAccount minimalAccount = new MinimalAccount(networkConfig.entryPoint);
        vm.stopBroadcast();
        return (helperConfig, minimalAccount);
    }
}
