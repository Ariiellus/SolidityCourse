// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title DEX Template
 * @author stevepham.eth and m00npapi.eth
 * @notice Empty DEX.sol that just outlines what features could be part of the challenge (up to you!)
 * @dev We want to create an automatic market where our contract will hold reserves of both ETH and 🎈 Balloons. These reserves will provide liquidity that allows anyone to swap between the assets.
 * NOTE: functions outlined here are what work with the front end of this challenge. Also return variable names need to be specified exactly may be referenced (It may be helpful to cross reference with front-end code function calls).
 */
contract DEX {
    /* ========== GLOBAL VARIABLES ========== */
    IERC20 token; //instantiates the imported contract
    mapping(address => uint256) public liquidityProvidedByUser;
    uint256 public totalERC20Liquidity;
    uint256 public totalETHLiquidity;
    uint256 public totalLiquidity;

    /* ========== EVENTS ========== */

    /**
     * @notice Emitted when ethToToken() swap transacted
     */
    event EthToTokenSwap(address swapper, uint256 tokenOutput, uint256 ethInput);

    /**
     * @notice Emitted when tokenToEth() swap transacted
     */
    event TokenToEthSwap(address swapper, uint256 tokensInput, uint256 ethOutput);

    /**
     * @notice Emitted when liquidity provided to DEX and mints LPTs.
     */
    event LiquidityProvided(address liquidityProvider, uint256 liquidityMinted, uint256 ethInput, uint256 tokensInput);

    /**
     * @notice Emitted when liquidity removed from DEX and decreases LPT count within DEX.
     */
    event LiquidityRemoved(
      address liquidityRemover,
      uint256 liquidityWithdrawn,
      uint256 tokensOutput,
      uint256 ethOutput
    );

    /* ========== ERRORS ========== */

    // error ERC20InsufficientAllowance(address, uint256, uint256);

    /* ========== CONSTRUCTOR ========== */

    constructor(address tokenAddr) {
        token = IERC20(tokenAddr); //specifies the token address that will hook into the interface and be used through the variable 'token'
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
     * @notice initializes amount of tokens that will be transferred to the DEX itself from the erc20 contract minter (and only them based on how Balloons.sol is written). Loads contract up with both ETH and Balloons.
     * @param tokens amount to be transferred to DEX
     * @return totalLiquidity is the number of LPTs minting as a result of deposits made to DEX contract
     * NOTE: since ratio is 1:1, this is fine to initialize the totalLiquidity (wrt to balloons) as equal to eth balance of contract.
     */
    function init(uint256 tokens) public payable returns (uint256) {
      require(totalLiquidity == 0, "DEX already has liquidity, no need to call this function");
      require(token.transferFrom(msg.sender, address(this), tokens), "Transfer failed");

      totalETHLiquidity = address(this).balance;
      totalERC20Liquidity = tokens;
      liquidityProvidedByUser[msg.sender] = Math.sqrt(totalERC20Liquidity * totalETHLiquidity); // follows sqrt(x * y) = liquidity
      totalLiquidity = liquidityProvidedByUser[msg.sender];
      return totalLiquidity;
    }

    /**
     * @notice returns yOutput, or yDelta for xInput (or xDelta)
     * @dev Follow along with the [original tutorial](https://medium.com/@austin_48503/%EF%B8%8F-minimum-viable-exchange-d84f30bd0c90) Price section for an understanding of the DEX's pricing model and for a price function to add to your contract. You may need to update the Solidity syntax (e.g. use + instead of .add, * instead of .mul, etc). Deploy when you are done.
     */
    function price(uint256 xInput, uint256 xReserves, uint256 yReserves) public pure returns (uint256 yOutput) {

      // xReserves = the token we are swapping (the token we are "selling")
      // yReserves = the token we are getting (the token we are "buying")

      require(xInput > 0, "Input cannot be 0");
      require(xReserves > 0 && yReserves > 0, "Reserves cannot be 0");

      uint256 fee = 30; // 0.3% fee
      uint256 inputAfterFee = xInput * (10000 - fee) / 10000; // apply the fee to the input
      yOutput = (inputAfterFee * yReserves / (xReserves + inputAfterFee));

      return yOutput;
    }

    /**
     * @notice returns liquidity for a user.
     * NOTE: this is not needed typically due to the `liquidity()` mapping variable being public and having a getter as a result. This is left though as it is used within the front end code (App.jsx).
     * NOTE: if you are using a mapping liquidity, then you can use `return liquidity[lp]` to get the liquidity for a user.
     * NOTE: if you will be submitting the challenge make sure to implement this function as it is used in the tests.
     */
    function getLiquidity(address lp) public view returns (uint256) {
      return liquidityProvidedByUser[lp];
    }

    /**
     * @notice sends Ether to DEX in exchange for $BAL
     */
    function ethToToken() public payable returns (uint256 tokenOutput) {
      require(msg.value > 0, "ETH Input cannot be 0");
      require(totalETHLiquidity > 0 && totalERC20Liquidity > 0, "DEX must have liquidity"); // I forgot to add this check.
      
      uint256 ethInput = msg.value;

      tokenOutput = price(ethInput, totalETHLiquidity, totalERC20Liquidity); // if we use the price function with 0.3% fee

      // update the liquidity pool
      totalETHLiquidity += ethInput;
      totalERC20Liquidity -= tokenOutput;
      token.transfer(msg.sender, tokenOutput);
      emit EthToTokenSwap(msg.sender, tokenOutput, ethInput);
      
      return tokenOutput; // I forgot to return the tokenOutput
    }

    /**
     * @notice sends $BAL tokens to DEX in exchange for Ether
     */
    function tokenToEth(uint256 tokenInput) public returns (uint256 ethOutput) {
      require(tokenInput > 0, "ERC20 Input cannot be 0");
      require(tokenInput <= token.balanceOf(msg.sender), "Insufficient ERC20 balance");
      require(token.allowance(msg.sender, address(this)) >= tokenInput, "Insufficient allowance"); // It's better to check the allowance first, otherwise the transfer will revert and the user will lose the ETH sent.
      require(totalETHLiquidity > 0 && totalERC20Liquidity > 0, "DEX must have liquidity"); // I forgot to add this check.

      ethOutput = price(tokenInput, totalERC20Liquidity, totalETHLiquidity);
      require(token.transferFrom(msg.sender, address(this), tokenInput), "Transfer failed"); // transfer the tokens to the DEX

      // update the liquidity pool

      totalERC20Liquidity += tokenInput;
      totalETHLiquidity -= ethOutput;

      (bool success, ) = msg.sender.call{value: ethOutput}("");
      require(success, "ETH transfer failed");

      emit TokenToEthSwap(msg.sender, tokenInput, ethOutput);
      return ethOutput; // I forgot to return the ethOutput
    }

    /**
     * @notice allows deposits of $BAL and $ETH to liquidity pool
     * NOTE: parameter is the msg.value sent with this function call. That amount is used to determine the amount of $BAL needed as well and taken from the depositor.
     * NOTE: user has to make sure to give DEX approval to spend their tokens on their behalf by calling approve function prior to this function call.
     * NOTE: Equal parts of both assets will be removed from the user's wallet with respect to the price outlined by the AMM.
     */
    function deposit() public payable returns (uint256 liquidityMinted) {
      // This function only can be used after call init function, otherwise it will revert

      require(msg.value > 0, "Input cannot be 0");
      // calculate the amount of tokens to deposit
      uint256 tokenDeposit = msg.value * totalERC20Liquidity / totalETHLiquidity + 1; // +1 to avoid division by 0

      require(token.balanceOf(msg.sender) >= tokenDeposit, "Insufficient ERC20 balance");
      require(token.allowance(msg.sender, address(this)) >= tokenDeposit, "Insufficient allowance");
      require(token.transferFrom(msg.sender, address(this), tokenDeposit), "ERC20 transfer failed");

      // store the previous liquidity values
      uint256 prevETHLiquidity = totalETHLiquidity;
      uint256 prevTokenLiquidity = totalERC20Liquidity;

      // update the liquidity pool values
      uint256 ethInput = msg.value;
      totalETHLiquidity += ethInput;
      totalERC20Liquidity += tokenDeposit;

      // calculate the liquidity minted, both in ETH and in ERC20 and then take the minimum of the two
      uint256 ethLiquidityProvided = totalLiquidity * ethInput / prevETHLiquidity;
      uint256 tokenLiquidityProvided = totalLiquidity * tokenDeposit / prevTokenLiquidity;
      liquidityMinted = Math.min(ethLiquidityProvided, tokenLiquidityProvided);

      liquidityProvidedByUser[msg.sender] += liquidityMinted;
      totalLiquidity += liquidityMinted; // total liquidity is the sum of all liquidity provided by users

      emit LiquidityProvided(msg.sender, liquidityMinted, ethInput, tokenDeposit);

      return liquidityMinted;
    }

    /**
     * @notice allows withdrawal of $BAL and $ETH from liquidity pool
     * NOTE: with this current code, the msg caller could end up getting very little back if the liquidity is super low in the pool. I guess they could see that with the UI.
     */
    function withdraw(uint256 amount) public returns (uint256 ethAmount, uint256 tokenAmount) {
      require(amount > 0, "Amount cannot be 0");
      require(liquidityProvidedByUser[msg.sender] >= amount, "Insufficient liquidity shares");

      ethAmount = totalETHLiquidity * amount / totalLiquidity;
      tokenAmount = totalERC20Liquidity * amount / totalLiquidity;

      require(totalETHLiquidity >= ethAmount, "Insufficient ETH liquidity");
      require(totalERC20Liquidity >= tokenAmount, "Insufficient ERC20 liquidity");

      totalETHLiquidity -= ethAmount;
      totalERC20Liquidity -= tokenAmount;

      liquidityProvidedByUser[msg.sender] -= amount;
      totalLiquidity -= amount;

      token.transfer(msg.sender, tokenAmount);
      (bool success, ) = msg.sender.call{value: ethAmount}("");
      require(success, "Liquidity Withdrawal failed");

      emit LiquidityRemoved(msg.sender, amount, tokenAmount, ethAmount);
    }
}
