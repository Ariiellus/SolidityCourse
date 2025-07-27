// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IFlashLoanRecipient} from "./Lending.sol";
import {Lending} from "./Lending.sol";
import {CornDEX} from "./CornDEX.sol";
import {Corn} from "./Corn.sol";


contract FlashLoanLiquidator is IFlashLoanRecipient {

  Lending i_lending;
  CornDEX i_cornDEX;
  Corn i_corn;

  constructor(address _lending, address _cornDEX, address _corn) {
      i_lending = Lending(_lending);
      i_cornDEX = CornDEX(_cornDEX);
      i_corn = Corn(_corn);
    }

	function executeOperation(uint256 amount, address initiator, address userToLiquidate) external returns (bool) {
      i_corn.approve(address(i_cornDEX), amount);
      i_lending.liquidate(userToLiquidate);

      uint256 ethBalanceDex = address(i_cornDEX).balance;
      uint256 cornBalanceDex = i_corn.balanceOf(address(i_cornDEX));
      uint256 neededETHInput = i_cornDEX.calculateXInput(amount, ethBalanceDex, cornBalanceDex);
        
      i_cornDEX.swap{value: neededETHInput}(neededETHInput); 
      i_corn.transfer(address(i_lending), i_corn.balanceOf(address(this)));

      if (address(this).balance > 0) {
          (bool success, ) = payable(initiator).call{value: address(this).balance}("");
          require(success, "ETH transfer failed");
      }

      return true;
  }

    receive() external payable {}
}
