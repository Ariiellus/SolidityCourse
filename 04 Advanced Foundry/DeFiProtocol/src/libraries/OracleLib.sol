// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/*
 * @title OracleLib
 * @author @Ariiellus
 * @notice This library is used to check the Chainlink Oracle for stale data
 * If a price is stale, the function will revert and render the DSCEngine unusable - this is by design
*/

library OracleLib {
    error OracleLib__StalePrice();
    uint256 private constant TIMEOUT = 1 hours;
    
    function stalePriceCheck(AggregatorV3Interface priceFeed) public view returns(uint80, int256, uint256, uint256, uint80) {
        (uint80 roundId, int256 price, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = priceFeed.latestRoundData();
        
        uint256 secondsSinceLastUpdate = block.timestamp - updatedAt;
        if (secondsSinceLastUpdate > TIMEOUT) {
            revert OracleLib__StalePrice();
        }
        return (roundId, price, startedAt, updatedAt, answeredInRound);
    }
}