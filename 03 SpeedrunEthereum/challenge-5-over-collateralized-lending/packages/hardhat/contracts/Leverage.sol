// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Lending } from "./Lending.sol";
import { CornDEX } from "./CornDEX.sol";
import { Corn } from "./Corn.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import "hardhat/console.sol";

/**
 * @notice For Side quest only
 * @notice This contract is used to leverage a user's position by borrowing CORN from the Lending contract
 * then borrowing more CORN from the DEX to repay the initial borrow then repeating until the user has borrowed as much as they want
 */
contract Leverage {
    Lending i_lending;
    CornDEX i_cornDEX;
    Corn i_corn;
    address public owner;

    event LeveragedPositionOpened(address user, uint256 loops);
    event LeveragedPositionClosed(address user, uint256 loops);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    constructor(address _lending, address _cornDEX, address _corn) {
        i_lending = Lending(_lending);
        i_cornDEX = CornDEX(_cornDEX);
        i_corn = Corn(_corn);
        // Approve the DEX to spend the user's CORN
        i_corn.approve(address(i_cornDEX), type(uint256).max);
        // Approve the Lending contract to spend CORN for repayment
        i_corn.approve(address(i_lending), type(uint256).max);
    }
    
    /**
     * @notice Claim ownership of the contract so that no one else can change your position or withdraw your funds
     */
    function claimOwnership() public {
        owner = msg.sender;
    }

    /**
     * @notice Open a leveraged position, iteratively borrowing CORN, swapping it for ETH, and adding it as collateral
     * @param reserve The amount of ETH that we will keep in the contract as a reserve to prevent liquidation
     */
    function openLeveragedPosition(uint256 reserve) public payable onlyOwner {
        uint256 loops = 0;
        while (true) {
            uint256 balance = address(this).balance;
            
            if (balance <= reserve) {
                break;
            }

            uint256 collateralToAdd = balance - reserve; // Only will add the excess above the reserve
            uint256 maxBorrowAmount = i_lending.getMaxBorrowAmount(collateralToAdd);
            
            //adding security check to prevent infinite loops. If the max borrow amount is less than 1 CORN, stop the loop.
            if (maxBorrowAmount < 1e18) {
                console.log("Stopping: borrow amount too small");
                break;
            }

            i_lending.addCollateral{value: collateralToAdd}();
            console.log("balance added: ", collateralToAdd);

            i_lending.borrowCorn(maxBorrowAmount);
            console.log("Corn borrowed: ", maxBorrowAmount);

            i_cornDEX.swap(maxBorrowAmount);
            console.log("ETH swapped: ", address(this).balance);

            loops++;
        }
        emit LeveragedPositionOpened(msg.sender, loops);
    }

    /**
     * @notice Close a leveraged position, iteratively withdrawing collateral, swapping it for CORN, and repaying the lending contract until the position is closed
     */
    function closeLeveragedPosition() public onlyOwner {
        uint256 loops = 0;
        while (true) {
            uint256 currentDebt = i_lending.s_userBorrowed(address(this));
            uint256 currentCollateral = i_lending.s_userCollateral(address(this));

            if (currentDebt == 0) {
                console.log("No debt remaining");
                i_lending.withdrawCollateral(currentCollateral); // to withdraw the remaining ETH
                break;
            }
            
            // calculate max amount of ETH to withdraw
            uint256 withdrawableETH = i_lending.getMaxWithdrawCollateral(address(this));
            i_lending.withdrawCollateral(withdrawableETH);

            i_cornDEX.swap{value: withdrawableETH}(withdrawableETH); // swap ETH for CORN
            
            uint256 cornBalance = i_corn.balanceOf(address(this));
            uint256 amountToRepay = Math.min(cornBalance, currentDebt); // to repay the min value
            
            if (amountToRepay > 0) {
              i_lending.repayCorn(amountToRepay); // repay CORN
            } else {
              i_cornDEX.swap(i_corn.balanceOf(address(this)));
              break;
            }
            loops++;
        }
        emit LeveragedPositionClosed(msg.sender, loops);
    }

    /**
     * @notice Withdraw the ETH from the contract
     */
    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        require(success, "Failed to send Ether");
    }

    receive() external payable {}
}