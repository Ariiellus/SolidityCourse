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
    error PredictionMarket__InsufficientTokenReserve(Outcome _outcome, uint _amountToken);
    error PredictionMarket__TokenTransferFailed();
    error PredictionMarket__ETHTransferFailed();
    error PredictionMarket__InsufficientBalance(uint _tradingAmount, uint _userBalance);
    error PredictionMarket__InsufficientAllowance(uint _tradingAmount, uint _allowance);
    error PredictionMarket__InsufficientLiquidity();
    error PredictionMarket__InvalidPercentageToLock();

    //////////////////////////
    /// State Variables //////
    //////////////////////////

    enum Outcome {
        YES,
        NO
    }

    uint private constant PRECISION = 1e18;

    /// Checkpoint 2 ///
    string public s_question;
    uint public s_ethCollateral;
    uint public s_lpTradingRevenue;

    address public immutable i_oracle;
    uint public immutable i_initialTokenValue;
    uint public immutable i_percentageLocked;
    uint public immutable i_initialYesProbability;

    /// Checkpoint 3 ///
    PredictionMarketToken public immutable i_yesToken;
    PredictionMarketToken public immutable i_noToken;

    /// Checkpoint 5 ///
    address public s_winningToken;
    bool public s_isReported;

    /////////////////////////
    /// Events //////
    /////////////////////////

    event TokensPurchased(address indexed buyer, Outcome outcome, uint amount, uint ethAmount);
    event TokensSold(address indexed seller, Outcome outcome, uint amount, uint ethAmount);
    event WinningTokensRedeemed(address indexed redeemer, uint amount, uint ethAmount);
    event MarketReported(address indexed oracle, Outcome winningOutcome, address winningToken);
    event MarketResolved(address indexed resolver, uint totalEthToSend);
    event LiquidityAdded(address indexed provider, uint ethAmount, uint tokensAmount);
    event LiquidityRemoved(address indexed provider, uint ethAmount, uint tokensAmount);

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
    modifier amountGreaterThanZero(uint _amount) {
        if (_amount == 0) {
            revert PredictionMarket__AmountMustBeGreaterThanZero();
        }
        _;
    }

    modifier onlyNotOwner() {
        if (msg.sender == owner()) {
            revert PredictionMarket__OwnerCannotCall();
        }
        _;
    }

    //////////////////
    ////Constructor///
    //////////////////

    constructor(
        address _liquidityProvider,
        address _oracle,
        string memory _question,
        uint _initialTokenValue,
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
        uint initialTokenAmount = (msg.value * PRECISION) / _initialTokenValue;
        i_yesToken = new PredictionMarketToken("Yes Token", "Y", msg.sender, initialTokenAmount);
        i_noToken = new PredictionMarketToken("No Token", "N", msg.sender, initialTokenAmount);

        // We calculate the amount of tokens we lock to create the probability
        uint yesTokensLocked = (initialTokenAmount * i_initialYesProbability * i_percentageLocked * 2) / 10000;

        uint noTokensLocked = (initialTokenAmount * (100 - i_initialYesProbability) * i_percentageLocked * 2) / 10000;

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

        uint newMintedTokens = (msg.value * PRECISION) / i_initialTokenValue;

        i_yesToken.mint(address(this), newMintedTokens);
        i_noToken.mint(address(this), newMintedTokens);

        emit LiquidityAdded(msg.sender, msg.value, newMintedTokens);
    }

    /**
     * @notice Remove liquidity from the prediction market and burn respective tokens, if you remove liquidity before prediction ends you got no share of lpReserve
     * @dev Only the owner can remove liquidity and only if the prediction is not reported
     * @param _ethToWithdraw Amount of ETH to withdraw from liquidity pool
     */
    function removeLiquidity(uint _ethToWithdraw) external onlyOwner predictionNotReported {
        //// Checkpoint 4 ////
        // calculate the amount of tokens to burn
        uint tokensToBurn = (_ethToWithdraw * PRECISION) / i_initialTokenValue;

        if (tokensToBurn > i_yesToken.balanceOf(address(this)) || tokensToBurn > i_noToken.balanceOf(address(this))) {
            revert PredictionMarket__InsufficientTokenReserve(Outcome.YES, tokensToBurn);
        }

        s_ethCollateral -= _ethToWithdraw;

        i_yesToken.burn(address(this), tokensToBurn);
        i_noToken.burn(address(this), tokensToBurn);

        (bool success, ) = msg.sender.call{ value: _ethToWithdraw }("");
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
    function resolveMarketAndWithdraw() external onlyOwner predictionReported returns (uint ethRedeemed) {
        /// Checkpoint 6 ////

        if (s_isReported == false) {
            revert PredictionMarket__PredictionNotReported();
        }

        // Calculate the amount of winning tokens held by the contract
        uint tokensWon = s_winningToken == address(i_yesToken)
            ? i_yesToken.balanceOf(address(this))
            : i_noToken.balanceOf(address(this));

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

        (bool success, ) = msg.sender.call{ value: ethRedeemed }("");
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
    function buyTokensWithETH(
        Outcome _outcome,
        uint _amountTokenToBuy
    ) external payable predictionNotReported amountGreaterThanZero(_amountTokenToBuy) onlyNotOwner {
        /// Checkpoint 8 ////
        uint256 ethAmountToSend = getBuyPriceInEth(_outcome, _amountTokenToBuy);

        // Checks
        if (
            _amountTokenToBuy > i_yesToken.balanceOf(address(this)) ||
            _amountTokenToBuy > i_noToken.balanceOf(address(this))
        ) {
            revert PredictionMarket__InsufficientTokenReserve(Outcome.YES, _amountTokenToBuy);
        }
        if (msg.value != ethAmountToSend) {
            revert PredictionMarket__MustSendExactETHAmount();
        }

        s_lpTradingRevenue += ethAmountToSend;

        // Interactions
        if (_outcome == Outcome.YES) {
            i_yesToken.transfer(msg.sender, _amountTokenToBuy);
        } else {
            i_noToken.transfer(msg.sender, _amountTokenToBuy);
        }

        emit TokensPurchased(msg.sender, _outcome, _amountTokenToBuy, ethAmountToSend);
    }

    /**
     * @notice Sell prediction outcome tokens for ETH, need to call priceInETH function first to get right amount of tokens to buy
     * @param _outcome The possible outcome (YES or NO) to sell tokens for
     * @param _tradingAmount The amount of tokens to sell
     */
    function sellTokensForEth(
        Outcome _outcome,
        uint _tradingAmount
    ) external predictionNotReported amountGreaterThanZero(_tradingAmount) onlyNotOwner {
        /// Checkpoint 8 ////
        uint256 ethAmountToReceive = getSellPriceInEth(_outcome, _tradingAmount);
        PredictionMarketToken tokenOwned = _outcome == Outcome.YES ? i_yesToken : i_noToken;
        uint256 userBalance = tokenOwned.balanceOf(msg.sender);

        // Checks
        if (ethAmountToReceive > s_lpTradingRevenue) {
            revert PredictionMarket__InsufficientBalance(ethAmountToReceive, s_lpTradingRevenue);
        }

        if (userBalance < _tradingAmount) {
            revert PredictionMarket__InsufficientBalance(_tradingAmount, userBalance);
        }

        if (tokenOwned.allowance(msg.sender, address(this)) < _tradingAmount) {
            revert PredictionMarket__InsufficientAllowance(
                _tradingAmount,
                tokenOwned.allowance(msg.sender, address(this))
            );
        }

        tokenOwned.transferFrom(msg.sender, address(this), _tradingAmount);

        s_lpTradingRevenue -= ethAmountToReceive;

        (bool success, ) = msg.sender.call{ value: ethAmountToReceive }("");
        if (!success) {
            revert PredictionMarket__ETHTransferFailed();
        }

        emit TokensSold(msg.sender, _outcome, _tradingAmount, ethAmountToReceive);
    }

    /**
     * @notice Redeem winning tokens for ETH after prediction is resolved, winning tokens are burned and user receives ETH
     * @dev Only if the prediction is resolved
     * @param _amount The amount of winning tokens to redeem
     */
    function redeemWinningTokens(uint _amount) external {
        /// Checkpoint 9 ////
    }

    /**
     * @notice Calculate the total ETH price for buying tokens
     * @param _outcome The possible outcome (YES or NO) to buy tokens for
     * @param _tradingAmount The amount of tokens to buy
     * @return The total ETH price
     */
    function getBuyPriceInEth(Outcome _outcome, uint _tradingAmount) public view returns (uint) {
        /// Checkpoint 7 ////
        return _calculatePriceInEth(_outcome, _tradingAmount, false);
    }

    /**
     * @notice Calculate the total ETH price for selling tokens
     * @param _outcome The possible outcome (YES or NO) to sell tokens for
     * @param _tradingAmount The amount of tokens to sell
     * @return The total ETH price
     */
    function getSellPriceInEth(Outcome _outcome, uint _tradingAmount) public view returns (uint) {
        /// Checkpoint 7 ////
        return _calculatePriceInEth(_outcome, _tradingAmount, true);
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
    function _calculatePriceInEth(Outcome _outcome, uint _tradingAmount, bool _isSelling) private view returns (uint) {
        /// Checkpoint 7 ////
        (uint resultTokenReserve, uint otherTokenReserve) = _getCurrentReserves(_outcome);

        if (!_isSelling) {
            if (resultTokenReserve < _tradingAmount) {
                revert PredictionMarket__InsufficientLiquidity();
            }
        }

        uint totalTokenSupply = i_yesToken.totalSupply(); // both tokens have the same total supply
        uint probabilityBeforeTrade = _calculateProbability(resultTokenReserve, totalTokenSupply);

        // What happens before the trade?
        uint resultTokenSoldBefore = totalTokenSupply - resultTokenReserve;
        uint otherTokenSoldBefore = totalTokenSupply - otherTokenReserve;

        uint probabilityBefore = _calculateProbability(
            resultTokenSoldBefore,
            resultTokenSoldBefore + otherTokenSoldBefore
        );

        // What happens after the trade?
        uint newResultTokenReserve = _isSelling
            ? resultTokenReserve + _tradingAmount
            : resultTokenReserve - _tradingAmount;
        uint newOtherTokenReserve = otherTokenReserve;

        uint resultTokenSoldAfterTrade = totalTokenSupply - newResultTokenReserve;
        uint otherTokenSoldAfterTrade = totalTokenSupply - newOtherTokenReserve;

        uint probabilityAfterTrade = _calculateProbability(
            resultTokenSoldAfterTrade,
            resultTokenSoldAfterTrade + otherTokenSoldAfterTrade
        );

        uint averageProbability = (probabilityBefore + probabilityAfterTrade) / 2;

        return (i_initialTokenValue * averageProbability * _tradingAmount) / (PRECISION * PRECISION);
    }

    /**
     * @dev Internal helper to get the current reserves of the tokens
     * @param _outcome The possible outcome (YES or NO)
     * @return The current reserves of the tokens
     */
    function _getCurrentReserves(Outcome _outcome) private view returns (uint, uint) {
        /// Checkpoint 7 ////
        if (_outcome == Outcome.YES) {
            return (i_yesToken.balanceOf(address(this)), i_noToken.balanceOf(address(this)));
        } else {
            return (i_noToken.balanceOf(address(this)), i_yesToken.balanceOf(address(this)));
        }
    }

    /**
     * @dev Internal helper to calculate the probability of the tokens
     * @param tokensSold The number of tokens sold
     * @param totalSold The total number of tokens sold
     * @return The probability of the tokens
     */
    function _calculateProbability(uint tokensSold, uint totalSold) private pure returns (uint) {
        /// Checkpoint 7 ////
        return (tokensSold * PRECISION) / totalSold;
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
            uint initialTokenValue,
            uint yesTokenReserve,
            uint noTokenReserve,
            bool isReported,
            address yesToken,
            address noToken,
            address winningToken,
            uint ethCollateral,
            uint lpTradingRevenue,
            address predictionMarketOwner,
            uint initialProbability,
            uint percentageLocked
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
