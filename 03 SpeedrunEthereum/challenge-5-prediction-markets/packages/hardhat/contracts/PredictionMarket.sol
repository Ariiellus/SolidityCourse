//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import { PredictionMarketToken } from "./PredictionMarketToken.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract PredictionMarket is Ownable {
    /////////////////
    /// Errors //////
    /////////////////

    error PredictionMarket__MustProvideETHForInitialLiquidity();
    error PredictionMarket__InvalidProbability();
    error PredictionMarket__PredictionAlreadyReported();
    error PredictionMarket__OnlyOracleCanReport();
    error PredictionMarket__OwnerCannotCall();
    error PredictionMarket__PredictionNotReported();
    error PredictionMarket__InsufficientWinningTokens();
    error PredictionMarket__AmountMustBeGreaterThanZero();
    error PredictionMarket__MustSendExactETHAmount();
    error PredictionMarket__InsufficientTokenReserve(Outcome _outcome, uint256 _amountToken);
    error PredictionMarket__TokenTransferFailed();
    error PredictionMarket__ETHTransferFailed();
    error PredictionMarket__InsufficientBalance(uint256 _tradingAmount, uint256 _userBalance);
    error PredictionMarket__InsufficientAllowance(uint256 _tradingAmount, uint256 _allowance);
    error PredictionMarket__InsufficientLiquidity();
    error PredictionMarket__InvalidPercentageToLock();

    //////////////////////////
    /// State Variables //////
    //////////////////////////

    enum Outcome {
        YES,
        NO
    }

    uint256 private constant PRECISION = 1e18;

    /// Checkpoint 2 ///
    string public s_question;
    uint256 public s_ethCollateral;
    uint256 public s_lpTradingRevenue;

    address public immutable i_oracle;
    uint256 public immutable i_initialTokenValue;
    uint256 public immutable i_percentageLocked;
    uint256 public immutable i_initialYesProbability;

    /// Checkpoint 3 ///
    PredictionMarketToken public immutable i_yesToken;
    PredictionMarketToken public immutable i_noToken;

    /// Checkpoint 5 ///
    address public s_winningToken;
    bool public s_isReported;

    /////////////////////////
    /// Events //////
    /////////////////////////

    event TokensPurchased(address indexed buyer, Outcome outcome, uint256 amount, uint256 ethAmount);
    event TokensSold(address indexed seller, Outcome outcome, uint256 amount, uint256 ethAmount);
    event WinningTokensRedeemed(address indexed redeemer, uint256 amount, uint256 ethAmount);
    event MarketReported(address indexed oracle, Outcome winningOutcome, address winningToken);
    event MarketResolved(address indexed resolver, uint256 totalEthToSend);
    event LiquidityAdded(address indexed provider, uint256 ethAmount, uint256 tokensAmount);
    event LiquidityRemoved(address indexed provider, uint256 ethAmount, uint256 tokensAmount);

    /////////////////
    /// Modifiers ///
    /////////////////

    /// Checkpoint 5 ///
    modifier predictionNotReported() {
        if (s_isReported == true) {
            revert PredictionMarket__PredictionAlreadyReported();
        }
        _;
    }

    /// Checkpoint 6 ///

    modifier predictionReported() {
        if (s_isReported == false) {
            revert PredictionMarket__PredictionNotReported();
        }
        _;
    }

    /// Checkpoint 8 ///

    //////////////////
    ////Constructor///
    //////////////////

    constructor(
        address _liquidityProvider,
        address _oracle,
        string memory _question,
        uint256 _initialTokenValue,
        uint8 _initialYesProbability,
        uint8 _percentageToLock
    ) payable Ownable(_liquidityProvider) {
        /// Checkpoint 2 ////
        if (msg.value == 0) {
            revert PredictionMarket__MustProvideETHForInitialLiquidity();
        }
        if (_initialYesProbability >= 100 || _initialYesProbability == 0) {
            revert PredictionMarket__InvalidProbability();
        }

        if (_percentageToLock >= 100 || _percentageToLock == 0) {
            revert PredictionMarket__InvalidPercentageToLock();
        }

        i_oracle = _oracle;
        s_question = _question;
        i_initialTokenValue = _initialTokenValue;
        i_initialYesProbability = _initialYesProbability;
        i_percentageLocked = _percentageToLock;

        s_ethCollateral = msg.value;

        /// Checkpoint 3 ////
        // We create the tokens
        uint256 initialTokenAmount = msg.value * PRECISION / _initialTokenValue;
        i_yesToken = new PredictionMarketToken("Yes Token", "Y", msg.sender, initialTokenAmount);
        i_noToken = new PredictionMarketToken("No Token", "N", msg.sender, initialTokenAmount); 

        // We calculate the amount of tokens we lock to create the probability
        uint256 yesTokensLocked = (initialTokenAmount * i_initialYesProbability * i_percentageLocked * 2) / 10000;

        uint256 noTokensLocked = (initialTokenAmount * (100 - i_initialYesProbability) * i_percentageLocked * 2) / 10000;

        // Transfer the tokens to the contract
        bool success1 = i_yesToken.transfer(msg.sender, yesTokensLocked);
        bool success2 = i_noToken.transfer(msg.sender, noTokensLocked);

        if (!success1 || !success2) {
            revert PredictionMarket__TokenTransferFailed();
        }
    }

    /////////////////
    /// Functions ///
    /////////////////

    /**
     * @notice Add liquidity to the prediction market and mint tokens
     * @dev Only the owner can add liquidity and only if the prediction is not reported
     */
    function addLiquidity() external payable onlyOwner predictionNotReported {
        //// Checkpoint 4 ////
        if (msg.value == 0) {
            revert PredictionMarket__AmountMustBeGreaterThanZero();
        }

        s_ethCollateral += msg.value;

        uint256 newMintedTokens = msg.value * PRECISION / i_initialTokenValue;

        i_yesToken.mint(address(this), newMintedTokens);
        i_noToken.mint(address(this), newMintedTokens);

        emit LiquidityAdded(msg.sender, msg.value, newMintedTokens);
    }

    /**
     * @notice Remove liquidity from the prediction market and burn respective tokens, if you remove liquidity before prediction ends you got no share of lpReserve
     * @dev Only the owner can remove liquidity and only if the prediction is not reported
     * @param _ethToWithdraw Amount of ETH to withdraw from liquidity pool
     */
    function removeLiquidity(uint256 _ethToWithdraw) external onlyOwner predictionNotReported {
        //// Checkpoint 4 ////
        // calculate the amount of tokens to burn
        uint256 tokensToBurn = _ethToWithdraw * PRECISION / i_initialTokenValue;

        if(tokensToBurn > i_yesToken.balanceOf(address(this)) || tokensToBurn > i_noToken.balanceOf(address(this))) {
            revert PredictionMarket__InsufficientTokenReserve(Outcome.YES, tokensToBurn);
        }
        
        s_ethCollateral -= _ethToWithdraw;

        i_yesToken.burn(address(this), tokensToBurn);
        i_noToken.burn(address(this), tokensToBurn);

        (bool success, ) = msg.sender.call{value: _ethToWithdraw}("");
        if (!success) {
            revert PredictionMarket__ETHTransferFailed();
        }
        
        emit LiquidityRemoved(msg.sender, _ethToWithdraw, tokensToBurn);
    }

    /**
     * @notice Report the winning outcome for the prediction
     * @dev Only the oracle can report the winning outcome and only if the prediction is not reported
     * @param _winningOutcome The winning outcome (YES or NO)
     */
    function report(Outcome _winningOutcome) external predictionNotReported {
        //// Checkpoint 5 ////
        if (msg.sender != i_oracle) {
            revert PredictionMarket__OnlyOracleCanReport();
        }

        s_isReported = true;
        s_winningToken = _winningOutcome == Outcome.YES ? address(i_yesToken) : address(i_noToken);

        emit MarketReported(msg.sender, _winningOutcome, s_winningToken);
    }

    /**
     * @notice Owner of contract can redeem winning tokens held by the contract after prediction is resolved and get ETH from the contract including LP revenue and collateral back
     * @dev Only callable by the owner and only if the prediction is resolved
     * @return ethRedeemed The amount of ETH redeemed
     */
    function resolveMarketAndWithdraw() external onlyOwner predictionReported returns (uint256 ethRedeemed) {
        /// Checkpoint 6 ////
        
        if (s_isReported == false) {
            revert PredictionMarket__PredictionNotReported();
        }
        
        // Calculate the amount of winning tokens held by the contract
        uint256 tokensWon = s_winningToken == address(i_yesToken) ? i_yesToken.balanceOf(address(this)) : i_noToken.balanceOf(address(this));

        if (tokensWon > 0) {
            ethRedeemed = (tokensWon * i_initialTokenValue) / PRECISION;
            
            if (ethRedeemed > s_ethCollateral) {
                ethRedeemed = s_ethCollateral;
            }

            s_ethCollateral -= ethRedeemed;
            
            // Burn the winning tokens held by the contract
            if (s_winningToken == address(i_yesToken)) {
                i_yesToken.burn(address(this), tokensWon);
            } else {
                i_noToken.burn(address(this), tokensWon);
            }
        } 
        
        ethRedeemed = ethRedeemed + s_lpTradingRevenue;
        s_lpTradingRevenue = 0;

        (bool success, ) = msg.sender.call{value: ethRedeemed}("");
        if (!success) {
            revert PredictionMarket__ETHTransferFailed();
        }

        emit MarketResolved(msg.sender, ethRedeemed);

        return ethRedeemed;
    }
    /**
     * @notice Buy prediction outcome tokens with ETH, need to call priceInETH function first to get right amount of tokens to buy
     * @param _outcome The possible outcome (YES or NO) to buy tokens for
     * @param _amountTokenToBuy Amount of tokens to purchase
     */
    function buyTokensWithETH(Outcome _outcome, uint256 _amountTokenToBuy) external payable {
        /// Checkpoint 8 ////
    }

    /**
     * @notice Sell prediction outcome tokens for ETH, need to call priceInETH function first to get right amount of tokens to buy
     * @param _outcome The possible outcome (YES or NO) to sell tokens for
     * @param _tradingAmount The amount of tokens to sell
     */
    function sellTokensForEth(Outcome _outcome, uint256 _tradingAmount) external {
        /// Checkpoint 8 ////
    }

    /**
     * @notice Redeem winning tokens for ETH after prediction is resolved, winning tokens are burned and user receives ETH
     * @dev Only if the prediction is resolved
     * @param _amount The amount of winning tokens to redeem
     */
    function redeemWinningTokens(uint256 _amount) external {
        /// Checkpoint 9 ////
    }

    /**
     * @notice Calculate the total ETH price for buying tokens
     * @param _outcome The possible outcome (YES or NO) to buy tokens for
     * @param _tradingAmount The amount of tokens to buy
     * @return The total ETH price
     */
    function getBuyPriceInEth(Outcome _outcome, uint256 _tradingAmount) public view returns (uint256) {
        /// Checkpoint 7 ////
    }

    /**
     * @notice Calculate the total ETH price for selling tokens
     * @param _outcome The possible outcome (YES or NO) to sell tokens for
     * @param _tradingAmount The amount of tokens to sell
     * @return The total ETH price
     */
    function getSellPriceInEth(Outcome _outcome, uint256 _tradingAmount) public view returns (uint256) {
        /// Checkpoint 7 ////
        if (_tradingAmount == 0) {
            revert PredictionMarket__AmountMustBeGreaterThanZero();
    }

    /////////////////////////
    /// Helper Functions ///
    ////////////////////////

    /**
     * @dev Internal helper to calculate ETH price for both buying and selling
     * @param _outcome The possible outcome (YES or NO)
     * @param _tradingAmount The amount of tokens
     * @param _isSelling Whether this is a sell calculation
     */
    function _calculatePriceInEth(
        Outcome _outcome,
        uint256 _tradingAmount,
        bool _isSelling
    ) private view returns (uint256) {
        /// Checkpoint 7 ////
        (uint256 resultTokenReserve, uint256 otherTokenReserve) = _getCurrentReserves (_outcome);

        if (!_isSelling) {
            if (resultTokenReserve < _tradingAmount) {
                revert PredictionMarket__InsufficientLiquidity();
            }
        }

        uint256 totalTokenSupply = i_yesToken.totalSupply(); // both tokens have the same total supply
        uint256 probabilityBeforeTrade = _calculateProbability(resultTokenReserve, totalTokenSupply);

        // What happens before the trade?
        uint256 resultTokenSoldBefore = totalTokenSupply - resultTokenReserve;
        uint256 otherTokenSoldBefore = totalTokenSupply - resultTokenSoldBefore;

        uint256 probabilityBefore = _calculateProbability(currentTokenSoldBefore, totalTokensSoldBefore);

        // What happens after the trade?
        uint256 yesTokenReserves = _isSelling ? yesReserves + _tradingAmount : yesReserves - _tradingAmount;
        uint256 noTokenReserves = _isSelling ? noReserves + _tradingAmount : noReserves - _tradingAmount;

        uint256 yesTokenSoldAfterTrade = i_yesToken.totalSupply() - yesTokenReserves;
        uint256 noTokenSoldAfterTrade = i_noToken.totalSupply() - noTokenReserves;
        
        uint256 probabilityAfterTrade = _calculateProbability(yesTokenSoldAfterTrade, yesTokenSold);

        uint256 averageProbability = (probabilityBefore + probabilityAfter) / 2;

        return (i_initialTokenValue * probabilityAvg * _tradingAmount) / (PRECISION * PRECISION);
    }

    /**
     * @dev Internal helper to get the current reserves of the tokens
     * @param _outcome The possible outcome (YES or NO)
     * @return The current reserves of the tokens
     */
    function _getCurrentReserves(Outcome _outcome) private view returns (uint256, uint256) {
        /// Checkpoint 7 ////
        if (_outcome == Outcome.YES) {
            return (i_yesToken.balanceOf(address(this)), 0);
        } else {
            return (0, i_noToken.balanceOf(address(this)));
        }
    }

    /**
     * @dev Internal helper to calculate the probability of the tokens
     * @param tokensSold The number of tokens sold
     * @param totalSold The total number of tokens sold
     * @return The probability of the tokens
     */
    function _calculateProbability(uint256 tokensSold, uint256 totalSold) private pure returns (uint256) {
        /// Checkpoint 7 ////
        return (tokenSold * PRECISION) / totalSold;
    }

    /////////////////////////
    /// Getter Functions ///
    ////////////////////////

    /**
     * @notice Get the prediction details
     */
    function getPrediction()
        external
        view
        returns (
            string memory question,
            string memory outcome1,
            string memory outcome2,
            address oracle,
            uint256 initialTokenValue,
            uint256 yesTokenReserve,
            uint256 noTokenReserve,
            bool isReported,
            address yesToken,
            address noToken,
            address winningToken,
            uint256 ethCollateral,
            uint256 lpTradingRevenue,
            address predictionMarketOwner,
            uint256 initialProbability,
            uint256 percentageLocked
        )
    {
        /// Checkpoint 3 ////
        oracle = i_oracle;
        initialTokenValue = i_initialTokenValue;
        percentageLocked = i_percentageLocked;
        initialProbability = i_initialYesProbability;
        question = s_question;
        ethCollateral = s_ethCollateral;
        lpTradingRevenue = s_lpTradingRevenue;
        predictionMarketOwner = owner();
        yesToken = address(i_yesToken);
        noToken = address(i_noToken);
        outcome1 = i_yesToken.name();
        outcome2 = i_noToken.name();
        yesTokenReserve = i_yesToken.balanceOf(address(this));
        noTokenReserve = i_noToken.balanceOf(address(this));
        /// Checkpoint 5 ////
        isReported = s_isReported;
        winningToken = address(s_winningToken);
    }
}
