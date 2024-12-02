// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract FundMe {
    uint256 public minUsd = 5;

    // ETH Price feed = 0x689B1d8FB0c64ACFEeFA6BdE1d31f215e92B6fd4

    function fund() public payable {
                
        require(msg.value > minUsd, "You need to send more ETH"); 
        
        // 1^18 = 1 ETH
        // 1^12 = 1 Gwei

        // If msg.value < minUsd, the transaction will revert
        // Revert = Undo any actions that have been done and sent the remaining gas back



    }

    function withdraw() public {}
}