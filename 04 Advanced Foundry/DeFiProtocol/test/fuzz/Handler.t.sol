// SPDX-License-Identifier: MIT-License
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStablecoin} from "../../src/DecentralizedStablecoin.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

// Price Feed

contract Handler is Test {
    DSCEngine engine;
    DecentralizedStablecoin dsc;

    ERC20Mock weth;
    ERC20Mock wbtc;

    uint256 public timesMintIsCalled;
    address [] public usersWithDepositCollateral;
    MockV3Aggregator public wethUsdPriceFeed;
    MockV3Aggregator public wbtcUsdPriceFeed;

    uint256 MAX_DEPOSITE_SIZE = type(uint96).max;

    constructor(DSCEngine _engine, DecentralizedStablecoin _dsc, address _wethUsdPriceFeed, address _wbtcUsdPriceFeed) {
        engine = _engine;
        dsc = _dsc;

        address[] memory collateralTokens = engine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);
        
        wethUsdPriceFeed = MockV3Aggregator(_wethUsdPriceFeed);
        wbtcUsdPriceFeed = MockV3Aggregator(_wbtcUsdPriceFeed);
    }

    function mintDSC(uint256 amount, uint256 addressSeed) public{
      if (usersWithDepositCollateral.length == 0) {
        return;
      }

      address sender = usersWithDepositCollateral[addressSeed % usersWithDepositCollateral.length];
      (uint256 totalDSCMinted, uint256 collateralValueInUSD) = engine.getAccountInformation(sender);

      int256 maxDSCToMint = (int256(collateralValueInUSD) / 2) - int256(totalDSCMinted);
      if (maxDSCToMint < 0) {
        return;
      }

      amount = bound(amount, 0, uint256(maxDSCToMint));

      if (amount == 0) {
        return;
      }

      vm.startPrank(sender);
      engine.mintDSC(amount);
      vm.stopPrank();
      timesMintIsCalled++;
    }

    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSITE_SIZE);

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(engine), amountCollateral);
        engine.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();

        // consider a double push
        usersWithDepositCollateral.push(msg.sender);
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateralToRedeem = engine.getCollateralOfUser(msg.sender, address(collateral));
        amountCollateral = bound(amountCollateral, 0, maxCollateralToRedeem);

        if (amountCollateral == 0) {
            return;
        }

        engine.redeemCollateralForDSC(address(collateral), amountCollateral);
    }

    // function updateCollateralPrice(uint96 newPrice) public {
    //   int256 newPriceInt = int256(uint256(newPrice));
    //   wethUsdPriceFeed.updateAnswer(newPriceInt);
    //   wbtcUsdPriceFeed.updateAnswer(newPriceInt);
    // }

    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        }
        return wbtc;
    }
}
