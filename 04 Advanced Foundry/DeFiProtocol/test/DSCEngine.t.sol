// SPDX-License-Identifier: MIT-License

pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {DecentralizedStablecoin} from "../src/DecentralizedStablecoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {DeployDSCEngine} from "../script/DeployDSCEngine.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockMoreDebtDSC} from "./mocks/MockMoreDebtDSC.sol";
import {MockV3Aggregator} from "./mocks/MockV3Aggregator.sol";

contract DSCEngineTest is Test {
    DeployDSCEngine deployer;
    DecentralizedStablecoin dsc;
    DSCEngine engine;
    HelperConfig config;
    address ethUsdPriceFeed;
    address weth;
    address wbtcUsdPriceFeed;
    address wbtc;
    address public USER = makeAddr("USER");
    uint256 public amountCollateral = 10 ether;
    uint256 public constant STARTING_BALANCE = 10 ether;
    address public user = address(1);

    function setUp() public {
        deployer = new DeployDSCEngine();
        (engine, dsc, config) = deployer.run();
        (ethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc,) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_BALANCE);
    }

    //////////////////////////////////////
    // Constructor Tests ////////////////
    /////////////////////////////////////
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function test_RevertIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(wbtcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__MappingLengthsMustBeTheSame.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    /////////////////////////
    // Price Tests //////////
    /////////////////////////
    function test_getUSDValue() public view {
        uint256 ethAmount = 15 ether; // using ether instead of "e18"
        uint256 expectedUSD = 30000 ether; // 30k USD

        uint256 actualUSD = engine.getUSDValue(weth, ethAmount);
        assertEq(expectedUSD, actualUSD);
    }

    function test_GetTokenAmountFromUSD() public view {
        uint256 amountOfUSD = 100 ether;
        uint256 expectedWeth = 0.05 ether;

        uint256 actualWeth = engine.getTokenAmountFromUSD(weth, amountOfUSD);
        assertEq(expectedWeth, actualWeth);
    }

    //////////////////////////////////////
    // Deposit Collateral Tests //////////
    //////////////////////////////////////

    function test_RevertIfCollateralIsZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), amountCollateral);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function test_RevertsWithUnapprovedCollateral() public {
        ERC20Mock randomToken = new ERC20Mock();
        vm.startPrank(USER);
        randomToken.mint(USER, amountCollateral);
        randomToken.approve(address(engine), amountCollateral);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedCollateral.selector);
        engine.depositCollateral(address(randomToken), amountCollateral);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), amountCollateral);
        engine.depositCollateral(weth, amountCollateral);
        vm.stopPrank();
        _;
    }

    function test_DepositCollateralAndGetAccountInformation() public depositedCollateral {
        (uint256 totalDSCMinted, uint256 collateralValueInUSD) = engine.getAccountInformation(USER);
        uint256 expectedTotalDSCMinted = 0;
        uint256 expectedDepositAmount = engine.getTokenAmountFromUSD(weth, collateralValueInUSD);
        assertEq(totalDSCMinted, expectedTotalDSCMinted);
        assertEq(amountCollateral, expectedDepositAmount);
    }

    function test_DepositAndMint() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), amountCollateral);
        engine.depositCollateralAndMintDSC(weth, amountCollateral, 100 ether);
        (uint256 totalDSCMinted, uint256 collateralValueInUSD) = engine.getAccountInformation(USER);

        uint256 expectedTotalDSCMinted = 100 ether;
        uint256 expectedCollateralValueInUSD = amountCollateral * 2000;
        assertEq(totalDSCMinted, expectedTotalDSCMinted);
        assertEq(collateralValueInUSD, expectedCollateralValueInUSD);
        vm.stopPrank();
    }

    ///////////////////////////////
    // Redemption Tests ///////////
    ///////////////////////////////

    function test_RepayDSCAndGetCollateral() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), amountCollateral);
        engine.depositCollateralAndMintDSC(weth, amountCollateral, 100 ether);
        DecentralizedStablecoin(address(dsc)).approve(address(engine), 100 ether);
        engine.redeemCollateralForDSCAndBurnDSC(weth, amountCollateral, 100 ether);

        (uint256 totalDSCMinted, uint256 collateralValueInUSD) = engine.getAccountInformation(USER);
        uint256 expectedTotalDSCMinted = 0;
        uint256 expectedCollateralValueInUSD = 0;

        assertEq(totalDSCMinted, expectedTotalDSCMinted);
        assertEq(collateralValueInUSD, expectedCollateralValueInUSD);
        vm.stopPrank();
    }

    ///////////////////////////////
    // Liquidation Tests //////////
    //////////////////////////////

    function test_Liquidation() public {
        address alice = makeAddr("alice");
        address liquidator = makeAddr("liquidator");
        uint256 amountToMint = 100 ether;

        // Arrange - Setup
        MockMoreDebtDSC mockDsc = new MockMoreDebtDSC(ethUsdPriceFeed);
        tokenAddresses = [weth];
        priceFeedAddresses = [ethUsdPriceFeed];
        address owner = msg.sender;
        vm.prank(owner);
        DSCEngine mockDsce = new DSCEngine(tokenAddresses, priceFeedAddresses, address(mockDsc));
        mockDsc.mint(liquidator, amountToMint);
        mockDsc.transferOwnership(address(mockDsce));

        // Arrange - User (Alice) - will be liquidated
        ERC20Mock(weth).mint(alice, amountCollateral);
        vm.startPrank(alice);
        ERC20Mock(weth).approve(address(mockDsce), amountCollateral);
        mockDsce.depositCollateralAndMintDSC(weth, amountCollateral, amountToMint);
        vm.stopPrank();

        vm.startPrank(liquidator);
        // Approve the engine to spend the liquidator's DSC
        mockDsc.approve(address(mockDsce), amountToMint);

        // Act - Make Alice's position unhealthy by dropping ETH price
        int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18 (was $2000)
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);

        // Act/Assert - Try to liquidate Alice
        mockDsce.liquidate(alice, weth, amountToMint);
        vm.stopPrank();

        // Assert - Verify liquidation was successful
        (uint256 aliceDSCMinted,) = mockDsce.getAccountInformation(alice);
        assertEq(aliceDSCMinted, 0); // All debt was liquidated
        assertEq(ERC20Mock(weth).balanceOf(liquidator), amountCollateral - mockDsce.getCollateralOfUser(alice, weth));
    }
}
