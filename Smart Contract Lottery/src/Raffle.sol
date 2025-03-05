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
  error Raffle_NotEnoughTime();

  /* State Variables */
  uint16 private constant REQUEST_CONFIRMATIONS = 3;
  uint32 private constant NUM_WORDS = 1;
  uint private immutable i_entranceFee;
  uint private immutable i_interval;
  bytes32 private immutable i_keyHash;
  uint private immutable s_SubscriptionId;
  uint32 private immutable i_callbackGasLimit;
  address payable[] private s_players;
  uint private s_lastTimeStamp;

  /* Events */
  event RaffleEntered(address indexed player);

  constructor(
    uint entranceFee,
    uint interval,
    address vrfCoordinator,
    bytes32 gasLane,
    uint subscriptionId,
    uint32 callbackGasLimit
  ) VRFConsumerBaseV2Plus(vrfCoordinator) {
    i_entranceFee = entranceFee;
    i_interval = interval;
    s_lastTimeStamp = block.timestamp;
    i_keyHash = gasLane;
    s_SubscriptionId = subscriptionId;
    i_callbackGasLimit = callbackGasLimit;
  }

  function enterRaffle() external payable {
    if (msg.value < i_entranceFee) {
      revert Raffle_SendMoreETHToEnterRaffle();
    }

    s_players.push(payable(msg.sender));

    emit RaffleEntered(msg.sender);
  }

  function pickWinner() external {
    if ((block.timestamp - s_lastTimeStamp) < i_interval) {
      revert Raffle_NotEnoughTime();
    }
    VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
      keyHash: i_keyHash,
      subId: s_SubscriptionId,
      requestConfirmations: REQUEST_CONFIRMATIONS,
      callbackGasLimit: i_callbackGasLimit,
      numWords: NUM_WORDS,
      extraArgs: VRFV2PlusClient._argsToBytes(
        VRFV2PlusClient.ExtraArgsV1({ nativePayment: false })
      )
    });

    uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
  }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override{}
  /* Getter Function */

  function getEntranceFee() external view returns (uint) {
    return i_entranceFee;
  }
}