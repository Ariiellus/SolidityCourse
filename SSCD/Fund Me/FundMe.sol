// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {PriceConverter} from "./PriceConverter.sol";

contract FundMe {
    using PriceConverter for uint256;

    uint256 public minimumUsd = 5e18;

    address[] public funders;
    mapping(address funder => uint256 amountFunded) public addressToAmountFunded;

    // ETH Price feed = 0x689B1d8FB0c64ACFEeFA6BdE1d31f215e92B6fd4

    function fund() public payable {
        require(msg.value.getConversionRate() > minimumUsd, "You need to send more ETH"); // 1^18 = 1 ETH
        
        // 1^18 = 1 ETH
        // 1^12 = 1 Gwei

        // If msg.value < minUsd, the transaction will revert
        // Revert = Undo any actions that have been done and sent the remaining gas back

        funders.push(msg.sender); 
        addressToAmountFunded[msg.sender] = addressToAmountFunded[msg.sender] + msg.value;
    }

         function withdraw() public {
        // for loop
        //[1, 2, 3, 4] -> Elements
        // 0, 1, 2, 3 -> Indexex
        for(uint256 funderIndex = 0; funderIndex < funders.length; funderIndex++){
            address funder =funders[funderIndex];
            addressToAmountFunded[funder] = 0;
        }
    }
}