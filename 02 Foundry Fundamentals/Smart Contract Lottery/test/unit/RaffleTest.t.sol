// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstants} from "script/HelperConfig.s.sol";

contract RaffleTest is CodeConstants, Test {

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

  modifier raffleEntered() {
    vm.prank(PLAYER);
    raffle.enterRaffle{value: entranceFee}();
    vm.warp(block.timestamp + interval + 1);
    vm.roll(block.number + 1);
    _;
  }

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

  function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public raffleEntered {
    // Arrange
    raffle.performUpkeep("");

    // Act
    vm.expectRevert(Raffle.Raffle_RaffleNotOpen.selector);
    vm.prank(PLAYER);
    raffle.enterRaffle{value: entranceFee}();
  }

  function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
    // Arrange
    vm.warp(block.timestamp + interval + 1);
    vm.roll(block.number + 1);

    // Act
    (bool upkeepNeeded, ) = raffle.checkUpkeep("");
    assert(!upkeepNeeded);
  }

  function testCheckUpkeepReturnsFalseIfRaffleIsNotOpen() public raffleEntered {
    raffle.performUpkeep("");
    
    (bool upkeepNeeded, ) = raffle.checkUpkeep("");
    assert(!upkeepNeeded);
  }

  function testCheckUpkeepReturnsTrueIfEnoughTimeHasPassed() public raffleEntered {

    (bool upkeepNeeded, ) = raffle.checkUpkeep("");
    assert(upkeepNeeded);
  }

  function testCheckUpkeepReturnsFalseIfNotEnoughTimeHasPassed() public {
    vm.prank(PLAYER);
    raffle.enterRaffle{value: entranceFee}();    
    (bool upkeepNeeded, ) = raffle.checkUpkeep("");
    assert(!upkeepNeeded);
  }

  function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public raffleEntered {

    // Act / Assert
    raffle.performUpkeep("");
  }

  function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
    // Arrange
    uint256 currentBalance = 0;
    uint256 numPlayers = 0;
    uint256 s_raffleState = 0;

    vm.prank(PLAYER);
    raffle.enterRaffle{value: entranceFee}();
    currentBalance = currentBalance + entranceFee;
    numPlayers = 1;

    // Act / Assert
    vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numPlayers, s_raffleState));
    raffle.performUpkeep("");
  }

  function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestEvent() public raffleEntered {
    // Act
    vm.recordLogs();
    raffle.performUpkeep("");

    Vm.Log[] memory entries = vm.getRecordedLogs(); // Get the logs from the performUpkeep call
    bytes32 requestId = entries[1].topics[1]; // First event is from the vrfCoordinator, second topic is the indexed requestId.
    
    
    // Assert
    Raffle.RaffleState raffleState = raffle.getRaffleState();
    assert(uint256(requestId) != 0);
    assert(uint256(raffleState) == 1);
  }

  modifier skipFork() {
    if (block.chainid != ANVIL_CHAIN_ID) {
      return;
    }
    _;
  }

  function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId) public raffleEntered skipFork {
    vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
    VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
  }

  function testFulfillRandomWordsPicksAWinner() public raffleEntered skipFork {
    uint256 additionalEntrants = 3; 
    uint256 startingIndex = 1;
    address expectedWinner = address(1);

    for (uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
      address newPlayer = address(uint160(i));
      hoax(newPlayer, 1 ether);
      raffle.enterRaffle{value: entranceFee}();
    }

    uint256 startingTimeStamp = raffle.getLastTimeStamp();
    uint256 winnerStartingBalance = expectedWinner.balance;

    vm.recordLogs();
    raffle.performUpkeep("");

    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 requestId = entries[1].topics[1];
    VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

    address recentWinner = raffle.getRecentWinner();
    Raffle.RaffleState raffleState = raffle.getRaffleState();
    uint256 winnerBalance = recentWinner.balance;
    uint256 endingTimeStamp = raffle.getLastTimeStamp();
    uint256 prize = entranceFee * (additionalEntrants + 1);

    assert(recentWinner == expectedWinner);
    assert(uint256(raffleState) == 0);
    assert(winnerBalance == winnerStartingBalance + prize);
    assert(endingTimeStamp > startingTimeStamp);
  }
}
