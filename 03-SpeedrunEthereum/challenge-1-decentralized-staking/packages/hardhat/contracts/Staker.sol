// SPDX-License-Identifier: MIT
pragma solidity 0.8.20; //Do not change the solidity version as it negatively impacts submission grading

import "hardhat/console.sol";
import "./ExampleExternalContract.sol";

contract Staker {
    ExampleExternalContract public exampleExternalContract;
    event Stake(address indexed sender, uint256 amount);
    mapping ( address => uint256 ) public balances;
    uint256 public constant threshold = 1 ether;
    bool public executed;
    bool public openForWithdraw;

    uint256 public deadline = block.timestamp + 72 hours;

    constructor(address exampleExternalContractAddress) {
        exampleExternalContract = ExampleExternalContract(exampleExternalContractAddress);
    }

    function stake() public payable {
        require(executed == false, "Contract has already been completed");
        balances[msg.sender] += msg.value;
        emit Stake(msg.sender, msg.value);
    }

    function execute() public {
        require(balances[address(exampleExternalContract)] == 0, "Contract has already been completed");
        if (block.timestamp > deadline && address(this).balance >= threshold) {
            executed = true;
            exampleExternalContract.complete{value: address(this).balance}();
        }
        if (block.timestamp > deadline && address(this).balance < threshold) {
            openForWithdraw = true;
        }
    }

    function withdraw() public {
        require(openForWithdraw, "Withdraw is not open");
        uint256 userBalance = balances[msg.sender];
        require(userBalance > 0, "No balance to withdraw");
        
        balances[msg.sender] = 0; // SUPER IMPORTANTE ADD THIS LINE TO AVOID RE-ENTRANCY ATTACKS
        (bool sent, ) = msg.sender.call{value: userBalance}("");
        require(sent, "Failed to send Ether");
    }

    function timeLeft() public view returns (uint256) {
        if (block.timestamp >= deadline) {
            return 0;
        }
        return deadline - block.timestamp;
    }

    receive() external payable {
        stake();
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    // After some `deadline` allow anyone to call an `execute()` function
    // If the deadline has passed and the threshold is met, it should call `exampleExternalContract.complete{value: address(this).balance}()`

    // If the `threshold` was not met, allow everyone to call a `withdraw()` function to withdraw their balance

    // Add a `timeLeft()` view function that returns the time left before the deadline for the frontend

    // Add the `receive()` special function that receives eth and calls stake()
}
