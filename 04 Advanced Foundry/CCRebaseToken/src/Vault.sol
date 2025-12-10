// SPDX-License-Identifier: MIT 

pragma solidity ^0.8.24; 

import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract Vault {

	IRebaseToken private immutable I_REBASE_TOKEN;
	
	event Vault_Deposited(address indexed _user, uint256 _amount);
	event Vault_Withdrawn(address indexed _user, uint256 _amount);

	constructor(IRebaseToken _rebaseToken) {
		I_REBASE_TOKEN = _rebaseToken;
	}

	receive() external payable {}

	function deposit() external payable {
		// Deposit the amount into the vault
		uint256 interestRate = I_REBASE_TOKEN.getInterestRate();
		I_REBASE_TOKEN.mint(msg.sender, msg.value, interestRate);
		emit Vault_Deposited(msg.sender, msg.value);
	}

  function withdraw(uint256 _amount) external {
    I_REBASE_TOKEN.burn(msg.sender, _amount);
    
    (bool success, ) = payable(msg.sender).call{value: _amount}("");
    require(success, "ETH transfer failed");
    
    emit Vault_Withdrawn(msg.sender, _amount);
  }

	function getRebaseToken() external view returns (address) {
		return address(I_REBASE_TOKEN);
	}

}