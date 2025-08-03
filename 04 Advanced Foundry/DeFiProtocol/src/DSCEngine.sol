// SPDX-License-Identifier: MIT-License
pragma solidity ^0.8.26;

import {DecentralizedStablecoin} from "./DecentralizedStablecoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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

    // state variables
    mapping(address user => mapping(address asset => uint256 amount)) private s_collateral;
    mapping(address user => uint256 amountDSCMinted) private s_DSCMinted; // user => amountDSCMinted
    mapping(address token => address priceFeed) private s_priceFeeds;

    // events
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

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
        }
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

    function mintDSC() external {}

    function burnDSC() external {}

    function liquidate() external {}

    // Getter functions
    function getHealthFactor() external view returns (uint256) {}

    function getDSCRate() external view returns (uint256) {}
}
