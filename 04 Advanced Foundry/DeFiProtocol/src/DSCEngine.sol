// SPDX-License-Identifier: MIT-License
pragma solidity ^0.8.26;

import {DecentralizedStablecoin} from "./DecentralizedStablecoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {OracleLib} from "./libraries/OracleLib.sol";

/**
 * @title DSCEngine
 * @author @Ariiellus
 * @notice This is the contract responsible for minting and burning DSC while maintaining peg at all times. The system should be overcollateralized at all times.
 */
contract DSCEngine is ReentrancyGuard {
    // errors
    error DSCEngine__NotEnoughCollateral();
    error DSCEngine__MintFailed();
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__NotAllowedCollateral();
    error DSCEngine__MappingLengthsMustBeTheSame();
    error DSCEngine__TransferFailed();
    error DSCEngine__HealthFactorIsBroken(uint256 healthFactor);
    error DSCEngine__HealthFactorIsOk(uint256 healthFactor);

    // state variables
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200% overcollateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 10; // 10% bonus for liquidators

    DecentralizedStablecoin private immutable i_dsc;
    mapping(address user => mapping(address asset => uint256 amount)) private s_collateral;
    mapping(address user => uint256 amountDSCMinted) private s_DSCMinted; // user => amountDSCMinted
    mapping(address token => address priceFeed) private s_priceFeeds;
    address[] private s_collateralTokens;

    // events
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(
        address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount
    );
    event DSCMinted(address indexed user, uint256 indexed amountDSCToMint);
    event DSCBurned(address indexed user, uint256 indexed amountDSCToBurn);
    event UserLiquidated(
        address indexed liquidator, address indexed user, address indexed token, uint256 totalCollateralToRedeem
    );

    error DSCEngine__HealthFactorNotImproved(uint256 healthFactor);

    // modifiers
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier allowedCollateral(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__NotAllowedCollateral();
        }
        _;
    }

    // functions
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__MappingLengthsMustBeTheSame();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_dsc = DecentralizedStablecoin(dscAddress);
    }

    /*
     * @param tokenCollateralAddress The address of the token to deposit as collateral
     * @param amountCollateral The amount of the token to deposit
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        allowedCollateral(tokenCollateralAddress)
        nonReentrant
    {
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        s_collateral[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
    }

    function mintDSC(uint256 amountDSCToMint) public moreThanZero(amountDSCToMint) {
        s_DSCMinted[msg.sender] += amountDSCToMint;
        _healthFactorIsBroken(msg.sender);

        bool minted = DecentralizedStablecoin(i_dsc).mint(msg.sender, amountDSCToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }

        emit DSCMinted(msg.sender, amountDSCToMint);
    }

    /*
     * @param tokenCollateralAddress The address of the token to deposit as collateral
     * @param amountCollateral The amount of the token to deposit
     * @param amountDSCToMint The amount of DSC to mint
     * @notice This function combines depositCollateral and mintDSC functions
     */
    function depositCollateralAndMintDSC(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDSCToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDSC(amountDSCToMint);
    }

    function redeemCollateralForDSC(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
    {
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
        _healthFactorIsBroken(msg.sender);
    }

    function burnDSC(uint256 amountDSCToBurn) public moreThanZero(amountDSCToBurn) {
        _burnDSC(amountDSCToBurn, msg.sender, msg.sender);
        _healthFactorIsBroken(msg.sender);
    }

    /*
     * @param tokenCollateralAddress The address of the token to redeem as collateral
     * @param amountCollateral The amount of the token to redeem as collateral
     * @param amountDSCToBurn The amount of DSC to burn
     * @notice This function combines burnDSC and redeemCollateralForDSC functions
     */
    function redeemCollateralForDSCAndBurnDSC(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDSCToBurn
    ) external moreThanZero(amountCollateral) moreThanZero(amountDSCToBurn) {
        burnDSC(amountDSCToBurn);
        redeemCollateralForDSC(tokenCollateralAddress, amountCollateral);
    }

    /*
     * @param userToLiquidate The address of the user to liquidate
     * @param tokenCollateralAddress The address of the token to liquidate as collateral
     * @param debtToCover The amount of DSC to cover
     * @notice This function liquidates a user's position if their health factor is below the minimum health factor
     */
    function liquidate(address userToLiquidate, address tokenCollateralAddress, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        nonReentrant
    {
        // check if the position is healthy
        uint256 initialUserHealthFactor = _healthFactor(userToLiquidate);
        if (initialUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorIsOk(uint256(initialUserHealthFactor));
        }

        // pay back the debt
        uint256 tokenAmountFromUser = getTokenAmountFromUSD(tokenCollateralAddress, debtToCover);
        if (DecentralizedStablecoin(i_dsc).balanceOf(msg.sender) < s_DSCMinted[userToLiquidate]) {
            revert DSCEngine__NotEnoughCollateral();
        }
        _burnDSC(debtToCover, userToLiquidate, msg.sender);
        uint256 bonusCollateral = (tokenAmountFromUser * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;

        // take the collateral
        uint256 totalCollateralToRedeem = tokenAmountFromUser + bonusCollateral;
        _redeemCollateral(tokenCollateralAddress, totalCollateralToRedeem, userToLiquidate, msg.sender);

        uint256 newUserHealthFactor = _healthFactor(userToLiquidate);
        if (newUserHealthFactor <= initialUserHealthFactor) {
            revert DSCEngine__HealthFactorNotImproved(uint256(newUserHealthFactor));
        }
        _healthFactorIsBroken(userToLiquidate);

        emit UserLiquidated(msg.sender, userToLiquidate, tokenCollateralAddress, totalCollateralToRedeem);
    }

    // Getter functions
    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }

    /*
     * @notice Low level function that allows for the redemption of collateral
     * @param tokenCollateralAddress The address of the token to redeem as collateral
     * @param amountCollateral The amount of the token to redeem as collateral
     * @param from The address of the user to redeem the collateral from
     * @param to The address of the user to redeem the collateral to
     */
    function _redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral, address from, address to)
        private
    {
        s_collateral[from][tokenCollateralAddress] -= amountCollateral;
        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);
    }

    /*
     * @notice Low level function that allows for the burning of DSC
     * @param amountDSCToBurn The amount of DSC to burn
     * @param onBehalfOf The address of the user to burn the DSC on behalf of
     * @param from The address of the user to burn the DSC from
     */
    function _burnDSC(uint256 amountDSCToBurn, address onBehalfOf, address from) private {
        s_DSCMinted[onBehalfOf] -= amountDSCToBurn;
        bool success = DecentralizedStablecoin(i_dsc).transferFrom(from, address(this), amountDSCToBurn);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(amountDSCToBurn);
        emit DSCBurned(onBehalfOf, amountDSCToBurn);
    }

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDSCMinted, uint256 collateralValueInUSD)
    {
        totalDSCMinted = s_DSCMinted[user];
        collateralValueInUSD = getAccountCollateralValue(user);
    }

    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalDSCMinted, uint256 collateralValueInUSD) = _getAccountInformation(user);

        if (totalDSCMinted == 0) {
            return type(uint256).max;
        }

        if (collateralValueInUSD == 0) {
            return 0;
        }

        uint256 collateralAdjustedForThreshold =
            (collateralValueInUSD * (LIQUIDATION_PRECISION - LIQUIDATION_THRESHOLD)) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDSCMinted;
    }

    function _healthFactorIsBroken(address user) internal view returns (bool) {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorIsBroken(uint256(userHealthFactor));
        }
        return false;
    }

    function getTokenAmountFromUSD(address token, uint256 usdAmount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = OracleLib.stalePriceCheck(priceFeed);
        return (usdAmount * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUSD) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateral[user][token];
            totalCollateralValueInUSD += getUSDValue(token, amount);
        }
        return totalCollateralValueInUSD;
    }

    function getUSDValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = OracleLib.stalePriceCheck(priceFeed);
        return (uint256(price) * ADDITIONAL_FEED_PRECISION * amount) / PRECISION;
    }

    function getAccountInformation(address user)
        external
        view
        returns (uint256 totalDSMinted, uint256 collateralValueInUSD)
    {
        (totalDSMinted, collateralValueInUSD) = _getAccountInformation(user);
        return (totalDSMinted, collateralValueInUSD);
    }

    function getCollateralOfUser(address user, address token) external view returns (uint256) {
        return s_collateral[user][token];
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getTotalCollateralValue() external view returns (uint256) {
        uint256 totalCollateralValueInUSD = 0;
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateral[address(this)][token];
            totalCollateralValueInUSD += getUSDValue(token, amount);
        }
        return totalCollateralValueInUSD;
    }
}
