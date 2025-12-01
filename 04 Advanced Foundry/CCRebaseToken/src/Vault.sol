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
		I_REBASE_TOKEN.mint(msg.sender, msg.value);
		emit Vault_Deposited(msg.sender, msg.value);
	}

	function withdraw(uint256 _amount) external {
		// Withdraw the amount from the vault
	}

	function getRebaseToken() external view returns (address) {
		return address(I_REBASE_TOKEN);
	}

}