// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.28; 

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol"; 


/*
* @title Rebase Token
* @author @Ariiellus
* @notice This is a rebase token that incentivises users to deposit into a vault
* @notice The interest rate in the smart contract can only decrease
* @notice Each user will have their own interest rate that is the global interest rate at the time of deposit
*/
contract RebaseToken is ERC20 { 

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

    //////////////////////
    // Events ///////////
    //////////////////////
    event RebaseToken_InterestRateSet(uint256 _interestRate);

    //////////////////////
    // Constructor /////
    //////////////////////
    constructor() ERC20("Rebase Token", "RBT") {
    } 

    //////////////////////
    // Functions ////////
    //////////////////////
    function setInterestRate(uint256 _newInterestRate) external {
        // Set the interest rate
        if (_newInterestRate < interestRate) {
            revert RebaseToken_InterestRateCanOnlyDecreases(interestRate, _newInterestRate);
        }

        interestRate = _newInterestRate;
        emit RebaseToken_InterestRateSet(interestRate);   
    }

    /* 
    * @notice Mint tokens to a user
    * @param _to The address of the user
    * @param _amount The amount of tokens to mint
    */
    function mint(address _to, uint256 _amount) external {
        _mintAccurateInterest(_to);
        userInterestRate[_to] = interestRate;
        _mint(_to, _amount);
    }

    function _mintAccurateInterest(address _to) internal {

        lastUpdatedTimeStamp[_to] = block.timestamp;
    }
    
    function balanceOf(address _user) public view override returns (uint256 currentBalance) {
        currentBalance = super.balanceOf(_user) + _calculateUserAccumulatedInterestSinceLastUpdate(_user);

        return currentBalance;
    } 

    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user) internal view returns (uint256 interestEarned) {      
        if (lastUpdatedTimeStamp[_user] == 0) {
            return 0;
        }
        
        uint256 timeElapsed = block.timestamp - lastUpdatedTimeStamp[_user];
        uint256 baseUserInterestRate = userInterestRate[_user];
        uint256 baseBalance = super.balanceOf(_user);
        
        interestEarned = (baseBalance * baseUserInterestRate * timeElapsed) / (365 days * PRECISION);

        return interestEarned;
    }

    /* 
    * @notice Get the interest rate for a user
    * @param _user The address of the user
    * @return The interest rate for the user
    */
    function getUserInterestRate(address _user) external view returns (uint256) {
        return userInterestRate[_user];
    }

    function getUserBalance(address _user) public view returns (uint256) {
        return balanceOf(_user);
    }
}