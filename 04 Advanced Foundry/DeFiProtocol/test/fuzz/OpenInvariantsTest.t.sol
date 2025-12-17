// SPDX-License-Identifier: MIT-License

//what are our invariants?
// 1. Total supply of DSC should be less than the total value of all collateral deposited
// 2. Getter view functions should never revert

pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStablecoin} from "../../src/DecentralizedStablecoin.sol";
import {DeployDSCEngine} from "../../script/DeployDSCEngine.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Handler} from "./Handler.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {console2} from "forge-std/console2.sol";

contract OpenInvariantsTest is StdInvariant, Test {
    DeployDSCEngine deployer;
    DSCEngine engine;
    HelperConfig config;
    DecentralizedStablecoin dsc;
    Handler handler;

    address weth;
    address wbtc;
    address wethUsdPriceFeed;
    address wbtcUsdPriceFeed;

    function setUp() public {
        deployer = new DeployDSCEngine();
        (engine, dsc, config) = deployer.run();
        (wethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc,) = config.activeNetworkConfig();

        handler = new Handler(engine, dsc, wethUsdPriceFeed, wbtcUsdPriceFeed);
        
        targetContract(address(handler));
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        // get the value of all collateral in the protocol
        // compare it to all the debt (total supply of DSC)

        uint256 totalSupply = dsc.totalSupply();
        uint256 wethDeposited = ERC20Mock(weth).balanceOf(address(engine));
        uint256 wbtcDeposited = ERC20Mock(wbtc).balanceOf(address(engine));

        uint256 wethValue = engine.getUSDValue(weth, wethDeposited);
        uint256 wbtcValue = engine.getUSDValue(wbtc, wbtcDeposited);

        console2.log("Times mint is called: ", handler.timesMintIsCalled());

        assert(wethValue + wbtcValue >= totalSupply);
    }

    function invariant_getterFunctionsShouldNeverRevert() public view {
        engine.getCollateralTokens();
        engine.getCollateralOfUser(weth, msg.sender);
        engine.getCollateralOfUser(wbtc, msg.sender);
        engine.getAccountInformation(msg.sender);
        engine.getUSDValue(weth, 1);
        engine.getUSDValue(wbtc, 1);
    }
}