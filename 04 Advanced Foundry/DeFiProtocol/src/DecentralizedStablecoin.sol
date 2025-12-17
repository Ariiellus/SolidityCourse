// SPDX-License-Identifier: MIT-License
pragma solidity ^0.8.26;

import {ERC20, ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/*
 * @title DecentralizedStablecoin
 * @author @Ariiellus
 * @notice This is an example of a decentralized stablecoin pegged to the US dollar. It follows an algorithmic and uses ETH and BTC as collateral.
 */
contract DecentralizedStablecoin is ERC20Burnable, Ownable {
    error DecentralizedStablecoin__AmountMustBeGreaterThanZero();
    error DecentralizedStablecoin__BurnAmountExceedsBalance();
    error DecentralizedStablecoin__MintToZeroAddress();
    error DecentralizedStablecoin__MintAmountMustBeGreaterThanZero();

    constructor() ERC20("Decentralized StableCoin", "DSC") Ownable(msg.sender) {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount == 0) {
            revert DecentralizedStablecoin__AmountMustBeGreaterThanZero();
        }
        if (_amount > balance) {
            revert DecentralizedStablecoin__BurnAmountExceedsBalance();
        }

        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DecentralizedStablecoin__MintToZeroAddress();
        }
        if (_amount == 0) {
            revert DecentralizedStablecoin__MintAmountMustBeGreaterThanZero();
        }

        _mint(_to, _amount);
        return true;
    }
}
