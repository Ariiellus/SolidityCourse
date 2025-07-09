// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {NewToken} from "../src/NewToken.sol";

contract DeployNewToken is Script {
    uint256 public constant INITIAL_SUPPLY = 100e18;

    // Deploy the contract and mint 100 tokens to the deployer
    function run() public returns (NewToken) {
        vm.startBroadcast();
        NewToken NT = new NewToken(INITIAL_SUPPLY); // it will mint 100 tokens to the deployer
        vm.stopBroadcast();

        return NT;
    }
}
