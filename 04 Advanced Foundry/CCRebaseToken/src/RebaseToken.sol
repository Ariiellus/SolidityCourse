// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.30; 

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";


/*
* @title Rebase Token
* @author @Ariiellus
* @notice This is a rebase token that incentivises users to deposit into a vault
* @notice The interest rate in the smart contract can only decrease
* @notice Each user will have their own interest rate that is the global interest rate at the time of deposit
*/
contract RebaseToken is ERC20, Ownable, AccessControl {

    ///////////////
    // Errors /////
    ///////////////
    error RebaseToken_InterestRateCanOnlyDecreases(uint256 _oldInterestRate, uint256 _newInterestRate);

    //////////////////////
    // State variables //
    //////////////////////
    uint256 private interestRate = 5e10; // 50%
    mapping(address => uint256) private userInterestRate;
    mapping(address => uint256) private lastUpdatedTimeStamp;

    uint256 private constant PRECISION = 1e18;
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");

    //////////////////////
    // Events ///////////
    //////////////////////
    event RebaseToken_InterestRateSet(uint256 _interestRate);

    //////////////////////
    // Constructor /////
    //////////////////////
    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender) {}

    function grantMintAndBurnRole(address _user) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _user);
    }

    //////////////////////
    // Functions ////////
    //////////////////////
    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        // Set the interest rate
        if (_newInterestRate < interestRate) {
            revert RebaseToken_InterestRateCanOnlyDecreases(interestRate, _newInterestRate);
        }

        interestRate = _newInterestRate;
        emit RebaseToken_InterestRateSet(interestRate);   
    }

    function principalBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }

    /* 
    * @notice Mint tokens to a user
    * @param _to The address of the user
    * @param _amount The amount of tokens to mint
    */
    function mint(address _to, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAcruedInterest(_to);
        userInterestRate[_to] = interestRate;
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        if(_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }

        _mintAcruedInterest(_from);
        _burn(_from, _amount);
    }

    function _mintAcruedInterest(address _user) internal {
        uint256 previousBalance = super.balanceOf(_user);
        uint256 currentBalance = balanceOf(_user);
        uint256 balanceIncrease = currentBalance - previousBalance;
    
        lastUpdatedTimeStamp[_user] = block.timestamp;
        _mint(_user, balanceIncrease);
    }
    
    function balanceOf(address _user) public view override returns (uint256 currentBalance) {
        return super.balanceOf(_user) + _calculateUserAccumulatedInterestSinceLastUpdate(_user) / PRECISION;
    } 

    function transfer(address _recipient, uint256 _amount) public override returns (bool) {
        _mintAcruedInterest(msg.sender);
        _mintAcruedInterest(_recipient);

        if(_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        if (balanceOf(_recipient) == 0) {
            userInterestRate[_recipient] = userInterestRate[msg.sender];
        }

        return super.transfer(_recipient, _amount);
    }

    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        _mintAcruedInterest(_sender);
        _mintAcruedInterest(_recipient);

        if(_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }
        if (balanceOf(_recipient) == 0) {
            userInterestRate[_recipient] = userInterestRate[_sender];
        }

        return super.transferFrom(_sender, _recipient, _amount);
    }

    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user) internal view returns (uint256 interestEarned) {      
        if (lastUpdatedTimeStamp[_user] == 0) {
            return 0;
        }
        
        uint256 timeElapsed = block.timestamp - lastUpdatedTimeStamp[_user];
        interestEarned = (PRECISION + (userInterestRate[_user] * timeElapsed));
    }

    /* 
    * @notice Get the interest rate for a user
    * @param _user The address of the user
    * @return The interest rate for the user
    */
    function getUserInterestRate(address _user) external view returns (uint256) {
        return userInterestRate[_user];
    }

    function getInterestRate() external view returns (uint256) {
        return interestRate;
    }
}