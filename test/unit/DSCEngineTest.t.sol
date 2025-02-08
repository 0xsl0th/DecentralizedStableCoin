// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {DeployDSC} from "script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;
    address wbtc;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ETH_BALANCE = 10 ether;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc,) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ETH_BALANCE);
    }

    //////////////////////
    // Constructor Tests//
    //////////////////////
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);
        // assertEq(tokenAddresses.length, priceFeedAddresses.length);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    //////////////////////
    //   Modifier Tests //
    //////////////////////
    function testRevertsIfAmountNotMoreThanZero() public {
        uint256 amount = 0;
        vm.expectRevert(DSCEngine.DSCEngine__AmountMustBeGreaterThanZero.selector);
        dsce.burnDsc(amount);
    }

    //////////////////////
    //    Price Tests   //
    //////////////////////
    function testGetUsdValue() public view {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = dsce.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    function testGetTokenAmountFromUsd() public view {
        uint256 usdAmount = 100 ether;
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = dsce.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedWeth, actualWeth);
    }

    function testGetAccountCollateralValueInUSD() public {
        uint256 amount = 100 ether;
        ERC20Mock(weth).mint(USER, amount);

        vm.prank(USER);
        ERC20Mock(weth).approve(address(dsce), amount);
        vm.prank(USER);
        dsce.depositCollateral(weth, amount);

        (, uint256 collateralValueInUsd) = dsce.getAccountInformation(USER);
        uint256 expectedTotalCollateralValueInUsd = dsce.getAccountCollateralValueInUSD(USER);
        assertEq(collateralValueInUsd, expectedTotalCollateralValueInUsd);
    }

    /////////////////////////////
    // depositCollateral Tests //
    /////////////////////////////

    function testRevertsIfCollateralIsZero() public {
        uint256 amount = 0;
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__AmountMustBeGreaterThanZero.selector);
        dsce.depositCollateral(weth, amount);
        vm.stopPrank();
    }

    function testDepositCollateralRevertsWithUnapprovedCollateral() public {
        ERC20Mock randomToken = new ERC20Mock();
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dsce.depositCollateral(address(randomToken), AMOUNT_COLLATERAL);
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(USER);
        uint256 expectedTotalDscMinted = 0;
        uint256 expectedDepositAmount = dsce.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(totalDscMinted, expectedTotalDscMinted);
        console.log("Expected amount of collateral: ", AMOUNT_COLLATERAL);
        console.log("Expected Deposit Amount: ", expectedDepositAmount);
        // 10.000000000000000000
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);
    }

    function testRevertsIfAmountCollateralIsZero() public {
        uint256 amount = 0;
        uint256 amountDscToMint = 1;
        vm.expectRevert(DSCEngine.DSCEngine__AmountMustBeGreaterThanZero.selector);
        dsce.depositCollateralAndMintDsc(weth, amount, amountDscToMint);
    }

    function testRevertsIfMintAmountIsZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), 1);
        vm.expectRevert(DSCEngine.DSCEngine__AmountMustBeGreaterThanZero.selector);
        dsce.depositCollateralAndMintDsc(weth, 1, 0);
        vm.stopPrank();
    }

    /////////////////////////////
    // redeemCollateral Tests  //
    /////////////////////////////
    function testRevertsIfRedeemerNotMsgSender() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();

        address differentUser = address(1);
        vm.startPrank(differentUser);
        vm.expectRevert(DSCEngine.DSCEngine__OnlyMsgSenderCanRedeem.selector);
        dsce.redeemCollateral(USER, weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testRevertsIfBelowMinimumHealthFactor() public {
        // deposit collateral
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();

        // mint dsc
        vm.startPrank(USER);
        uint256 amountToMint = 1;
        dsce.mintDsc(amountToMint);
        vm.stopPrank();

        // redeem collateral
        vm.startPrank(USER);
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, 0));
        dsce.redeemCollateral(USER, weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testRevertsIfCollateralRedeemedAndNotEnoughDscIsBurnt() public {
        // deposit collateral
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        uint256 amountToMint = 10000;
        dsce.mintDsc(amountToMint);
        // approve DSC for burning
        DecentralizedStableCoin(dsc).approve(address(dsce), 10000);
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, 0));
        dsce.redeemCollateralForDsc(USER, weth, AMOUNT_COLLATERAL, 9999);
        vm.stopPrank();
    }

    function testRevertsIfUserRedeemsCollateralWithInsufficientDsc() public {
        // deposit collateral
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        uint256 amountToMint = 100;
        dsce.mintDsc(amountToMint);
        // approve DSC for burning
        DecentralizedStableCoin(dsc).approve(address(dsce), 100);
        vm.expectRevert(DSCEngine.DSCEngine__InsufficientDscToBurn.selector);
        dsce.redeemCollateralForDsc(USER, weth, AMOUNT_COLLATERAL, 101);
        vm.stopPrank();
    }

    function testUserCanRedeemFundsAfterBurningDsc() public {
        // deposit collateral
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        uint256 amountToMint = 100;
        dsce.mintDsc(amountToMint);
        // approve DSC for burning
        DecentralizedStableCoin(dsc).approve(address(dsce), 100);
        dsce.redeemCollateralForDsc(USER, weth, AMOUNT_COLLATERAL, 100);
        vm.expectRevert(DSCEngine.DSCEngine__AmountMustBeGreaterThanZero.selector);
        dsce.redeemCollateral(USER, weth, 0);
        vm.stopPrank();
    }

    /////////////////////////////
    //    liquidation Tests    //
    /////////////////////////////
    function testLiquidationIfHealthFactorOk() public {
        // deposit collateral
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        uint256 mintAmountToCoverDebt = AMOUNT_COLLATERAL / (2);
        dsce.mintDsc(mintAmountToCoverDebt);
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
        dsce.liquidate(weth, USER, mintAmountToCoverDebt);
        vm.stopPrank();
    }

    /////////////////////////////
    //   healthFactor Tests    //
    /////////////////////////////
    function testHealthFactorWhenUserDepositsWithoutMintingDSC() public {
        // deposit collateral
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
        dsce.liquidate(weth, USER, 1);
        vm.stopPrank();
    }
}
