//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";


abstract contract CodeConstants {
  /*VRF Mock Values */
  uint96 public MOCK_BASE_FEE = 0.25 ether;
  uint96 public MOCK_GAS_PRICE_LINK = 1e9;
  int256 public constant MOCK_WEI_PER_UINT_LINK = 1e18;

  uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
  uint256 public constant ANVIL_CHAIN_ID = 31337;
}

contract HelperConfig is CodeConstants, Script {
  error HelperConfig__InvalidChainId();

  struct NetworkConfig {
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;
  }

  NetworkConfig public localNetworkConfig;
  mapping(uint256 => NetworkConfig) public networkConfigs;

  constructor() {
    networkConfigs[SEPOLIA_CHAIN_ID] = getSepoliaNetworkConfig();
  }

  function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
    if(networkConfigs[chainId].vrfCoordinator != address(0)) {
      return networkConfigs[chainId];
    } else if (chainId == ANVIL_CHAIN_ID) {
      return getAnvilConfig();
    } else {
      revert HelperConfig__InvalidChainId();
    }
  }

  function getConfig() public returns (NetworkConfig memory) {
    return getConfigByChainId(block.chainid);
  }

  function getSepoliaNetworkConfig() public pure returns(NetworkConfig memory) {
    return NetworkConfig({
      entranceFee: 0.01 ether, // 1e16 = 1 * 10 ** 16
      interval: 30, // 30 seconds
      vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B, // From https://docs.chain.link/vrf/v2-5/supported-networks#ethereum-sepolia-testnet
      gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // From https://docs.chain.link/vrf/v2-5/supported-networks#ethereum-sepolia-testnet
      callbackGasLimit: 500000,
      subscriptionId: 0
    });
  }

  function getAnvilConfig() public returns(NetworkConfig memory) {
    if (localNetworkConfig.vrfCoordinator != address(0)) {
      return localNetworkConfig;
    }

    vm.startBroadcast();
    VRFCoordinatorV2_5Mock vrfCoordinatorMock = 
      new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UINT_LINK);
    vm.stopBroadcast();

    localNetworkConfig = NetworkConfig({
      entranceFee: 0.01 ether,
      interval: 30,
      vrfCoordinator: address(vrfCoordinatorMock),
      gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
      callbackGasLimit: 500000,
      subscriptionId: 0
    });
    return localNetworkConfig;
  }
}