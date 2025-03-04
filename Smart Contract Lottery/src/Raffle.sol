// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Sample Raffle Contract
 * @author Ariiellus
 * @notice This contract is part of the Cyfrin Updraft Foundry Fundamentals course
 * @dev Implements Chainlink VRFV2.5
 */

contract Raffle {
  /* Errors */
  error Raffle_SendMoreETHToEnterRaffle();
  error Raffle_NotEnoughTime();

  /* State Variables */
  uint256 private immutable i_entranceFee;
  uint256 private immutable i_interval;
  address payable[] private s_players;
  uint256 private s_lastTimeStamp;

  /* Events */
  event RaffleEntered(address indexed player);
  
  constructor(uint256 entranceFee, uint256 interval) {
    i_entranceFee = entranceFee;
    i_interval = interval;
    s_lastTimeStamp = block.timestamp;
  } 

  function enterRaffle() external payable {
    if(msg.value < i_entranceFee) {
      revert Raffle_SendMoreETHToEnterRaffle();
    }
    
    s_players.push(payable(msg.sender));
    
    emit RaffleEntered(msg.sender);

  }

  // adding "view" because currently pickWinner doesn't modify the state. Delete this later
  function pickWinner() external view{
    if((block.timestamp - s_lastTimeStamp) < i_interval) {
      revert Raffle_NotEnoughTime();
    }
  }

  /* Getter Function */

  function getEntranceFee() external view returns (uint256) {
    return i_entranceFee;
  }

}