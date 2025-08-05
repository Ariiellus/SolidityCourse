// SPDX-License-Identifier: MIT-License
pragma solidity ^0.8.26;

import {DecentralizedStablecoin} from "./DecentralizedStablecoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

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

    // state variables
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;

    DecentralizedStablecoin private immutable i_dsc;
    mapping(address user => mapping(address asset => uint256 amount)) private s_collateral;
    mapping(address user => uint256 amountDSCMinted) private s_DSCMinted; // user => amountDSCMinted
    mapping(address token => address priceFeed) private s_priceFeeds;
    address[] private s_collateralTokens;

    // events
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event DSCMinted(address indexed user, uint256 indexed amountDSCMinted);

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
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__MappingLengthsMustBeTheSame();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_dsc = new DecentralizedStablecoin(address(this));
    }

    /*
     * @param tokenCollateralAddress The address of the token to deposit as collateral
     * @param amountCollateral The amount of the token to deposit
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
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

    function depositCollateralAndMintDSC() external payable {}

    function redeemCollateralForDSC() external {}

    function mintDSC(uint256 amountDSCToMint) external moreThanZero(amountDSCToMint) {
        s_DSCMinted[msg.sender] += amountDSCToMint;
        _healthFactorIsBroken(msg.sender);

        bool minted = DecentralizedStablecoin(i_dsc).mint(msg.sender, amountDSCToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }

        emit DSCMinted(msg.sender, amountDSCToMint);
    }

    function burnDSC() external {}

    function liquidate() external {}

    // Getter functions
    function getHealthFactor() external view returns (uint256) {}

    function getDSCRate() external view returns (uint256) {}

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
        uint256 collateralAdjustedForThreshold =
            (collateralValueInUSD * (LIQUIDATION_PRECISION - LIQUIDATION_THRESHOLD)) / LIQUIDATION_PRECISION;
        return (totalDSCMinted * PRECISION) / collateralAdjustedForThreshold;
    }

    function _healthFactorIsBroken(address user) internal view returns (bool) {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorIsBroken(uint256(userHealthFactor));
        }
        return false;
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
        (, int256 price,,,) = priceFeed.latestRoundData();
        return (uint256(price) * ADDITIONAL_FEED_PRECISION * amount) / PRECISION;
    }
}
