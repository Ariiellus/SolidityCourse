// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract RaffleTest is Test {

  // State variables
  Raffle public raffle; // contract that we are testing
  HelperConfig public helperConfig; // helper contract that we are using to deploy the contract

  uint256 public entranceFee;
  uint256 public interval;
  address public vrfCoordinator;
  bytes32 public gasLane;
  uint256 public subscriptionId;
  uint32 public callbackGasLimit;

  address public PLAYER = makeAddr("player"); // testing address
  uint256 public constant STARTING_USER_BALANCE = 10 ether;
    /* Events */
  event RaffleEntered(address indexed player);
  event WinnerPicked(address indexed player);


  function setUp() external {
    DeployRaffle deployer = new DeployRaffle();
    (raffle, helperConfig) = deployer.deployContract();

    HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
    entranceFee = config.entranceFee;
    interval = config.interval;
    vrfCoordinator = config.vrfCoordinator;
    gasLane = config.gasLane;
    subscriptionId = config.subscriptionId;
    callbackGasLimit = config.callbackGasLimit;

    vm.deal(PLAYER, STARTING_USER_BALANCE);
  }

  function testRaffleInitializesInOpenState() public view {
    assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN); // This checks that the raffle is in the open state

  }

  function testRaffleRevertsWhenYouDontPayEnough() public {
    vm.prank(PLAYER);
    vm.expectRevert(Raffle.Raffle_SendMoreETHToEnterRaffle.selector);
    raffle.enterRaffle();
  }

  function testRaffleRecordsPlayerWhenTheyEnter() public {
    // Arrange
    vm.prank(PLAYER);
    raffle.enterRaffle{value: entranceFee}();
    address playerRecorded = raffle.getPlayer(0);
    assertEq(playerRecorded, PLAYER);
  }

  function testRaffleEmitsEvent() public {
    // Arrange
    vm.prank(PLAYER);
    vm.expectEmit(true, false, false, false, address(raffle));
    emit RaffleEntered(address(PLAYER));
    raffle.enterRaffle{value: entranceFee}();
  }

  function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
    // Arrange
    vm.prank(PLAYER);
    raffle.enterRaffle{value: entranceFee}();
    vm.warp(block.timestamp + interval + 1);
    vm.roll(block.number + 1);
    raffle.performUpkeep("");

    // Act
    vm.expectRevert(Raffle.Raffle_RaffleNotOpen.selector);
    vm.prank(PLAYER);
    raffle.enterRaffle{value: entranceFee}();

    // Assert
    assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
  }
}