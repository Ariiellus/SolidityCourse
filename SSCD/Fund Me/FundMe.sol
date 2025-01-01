// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {PriceConverter} from "./PriceConverter.sol";

error notOwner();
error callFailed();

contract FundMe {
    using PriceConverter for uint256;

    // wo constant 783,228 gas
    // w constant 762,891 gas

    uint256 public constant MINIMUM_USD = 5e18;

    address[] public funders;
    mapping(address funder => uint256 amountFunded)
        public addressToAmountFunded;

    // ETH Price feed = 0x689B1d8FB0c64ACFEeFA6BdE1d31f215e92B6fd4

    address public immutable i_owner;
    // wo immutable 762,903 gas
    // w immutable 739,720 gas
    constructor() {
        i_owner = msg.sender;
    }

    function fund() public payable {
        require(
            msg.value.getConversionRate() > MINIMUM_USD,
            "You need to send more ETH"
        ); // 1^18 = 1 ETH

        // 1^18 = 1 ETH
        // 1^12 = 1 Gwei

        // If msg.value < minUsd, the transaction will revert
        // Revert = Undo any actions that have been done and sent the remaining gas back

        funders.push(msg.sender);
        addressToAmountFunded[msg.sender] =
            addressToAmountFunded[msg.sender] +
            msg.value;
    }

    function withdraw() public onlyOwner {
        // for loop
        //[1, 2, 3, 4] -> Elements
        // 0, 1, 2, 3 -> Indexex
        for (
            uint256 funderIndex = 0;
            funderIndex < funders.length;
            funderIndex++
        ) {
            address funder = funders[funderIndex];
            addressToAmountFunded[funder] = 0;
        }

        // reset the array
        funders = new address[](0);

        // transfer, if this fails throw error, capped at 2300 gas
        // payable(msg.sender).transfer(address(this).balance);

        // send, if this fails returns boolean, capped at 2300 gas
        // bool = sendSuccess = payable(msg.sender).send(address(this).balance);
        // require(sendSuccess, "Send Failed");

        // call, if this fails returns bool
        (bool callSuccess, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        // require(callSuccess, "Call Failed");
        if (callSuccess) {
            revert callFailed();
        }
    }

    modifier onlyOwner() {
        // require(msg.sender == i_owner, "Sender is not owner!");

        // wo revert error 739,720 gas
        // w revert error 715,431 gas
        if (msg.sender != i_owner) {
            revert notOwner();
        }
        _;
    }

    receive() external payable {
        fund();
    }

    fallback() external payable {
        fund();
    }
}
