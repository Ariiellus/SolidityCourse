// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { VRFConsumerBaseV2Plus } from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import { VRFV2PlusClient } from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title Sample Raffle Contract
 * @author Ariiellus
 * @notice This contract is part of the Cyfrin Updraft Foundry Fundamentals course
 * @dev Implements Chainlink VRFV2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {
  /* Errors */
  error Raffle_SendMoreETHToEnterRaffle();
  error Raffle_TransferFailed();
  error Raffle_RaffleNotOpen();
  error Raffle__UpkeepNotNeeded(uint256 balance, uint256 playersLength, uint256 raffleState);

  /* Type Declarations */
  enum RaffleState {
    OPEN,
    CALCULATING
  }

  /* State Variables */
  uint16 private constant REQUEST_CONFIRMATIONS = 3;
  uint32 private constant NUM_WORDS = 1;
  uint private immutable i_entranceFee;
  uint private immutable i_interval;
  bytes32 private immutable i_keyHash;
  uint private immutable i_SubscriptionId;
  uint32 private immutable i_callbackGasLimit;
  address payable[] private s_players;
  uint private s_lastTimeStamp;
  address private s_recentWinner;
  RaffleState private s_RaffleState;

  /* Events */
  event RaffleEntered(address indexed player);
  event WinnerPicked(address indexed player);

  constructor(
    uint256 entranceFee,
    uint256 interval,
    address vrfCoordinator,
    bytes32 gasLane,
    uint256 subscriptionId,
    uint32 callbackGasLimit
  ) VRFConsumerBaseV2Plus(vrfCoordinator) {
    i_entranceFee = entranceFee;
    i_interval = interval;
    i_keyHash = gasLane;
    i_callbackGasLimit = callbackGasLimit;
    i_SubscriptionId = subscriptionId;

    s_lastTimeStamp = block.timestamp;
    s_RaffleState = RaffleState.OPEN;
  }


  function enterRaffle() external payable {
    if (msg.value < i_entranceFee) {
      revert Raffle_SendMoreETHToEnterRaffle();
    }
    if (s_RaffleState != RaffleState.OPEN) {
      revert Raffle_RaffleNotOpen();
    }

    s_players.push(payable(msg.sender));

    emit RaffleEntered(msg.sender);
  }



  function checkUpkeep(bytes memory) 
    public 
    view 
    returns (bool upkeepNeeded, bytes memory) 
  {
    bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
    bool isOpen = s_RaffleState == RaffleState.OPEN;
    bool hasBalance = address(this).balance > 0;
    bool hasPlayers = s_players.length > 0;
    upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
    return (upkeepNeeded, "");
  }

  function performUpkeep(bytes calldata) external {

    (bool upkeepNeeded, ) = checkUpkeep("");
    if (!upkeepNeeded) {
      revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_RaffleState));
    }

    s_RaffleState = RaffleState.CALCULATING;
    VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
      keyHash: i_keyHash,
      subId: i_SubscriptionId,
      requestConfirmations: REQUEST_CONFIRMATIONS,
      callbackGasLimit: i_callbackGasLimit,
      numWords: NUM_WORDS,
      extraArgs: VRFV2PlusClient._argsToBytes(
        VRFV2PlusClient.ExtraArgsV1({ nativePayment: false })
      )
    });
    s_vrfCoordinator.requestRandomWords(request);
  }

  function fulfillRandomWords(uint256, uint256[] calldata randomWords) internal override{
    // Check

    // Effect (Internal Contract State)
    uint256 indexOfWinner = randomWords[0] % s_players.length;
    address payable recentWinner = s_players[indexOfWinner];
    s_recentWinner = recentWinner;
    s_RaffleState = RaffleState.OPEN;
    s_players = new address payable[](0);
    s_lastTimeStamp = block.timestamp;
    emit WinnerPicked(s_recentWinner);

    // Interactions (External Contracts Interaction)
    (bool success,) = recentWinner.call{value: address(this).balance}("");
    if (!success) {
      revert Raffle_TransferFailed();
    }
  }

  /* Getter Function */
  function getEntranceFee() external view returns (uint) {
    return i_entranceFee;
  }
}