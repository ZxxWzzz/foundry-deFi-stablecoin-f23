// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";

contract DscEngineTest is Test {
    DeployDSC deployer;
    HelperConfig config;

    DecentralizedStableCoin dsc;
    DSCEngine dsce;

    address ethUsdPriceFeed;
    address weth;
    address btcUsdPriceFeed;
    address wbtc;

    address public user = address(1);
    address public user2 = address(2);

    uint256 amountCollateral = 10 ether;
    uint256 amountToMint = 100 ether;

    uint256 public constant STARTING_USER_BALANCE = 100 ether;

    // address wbtcUsdPriceFeed;

    //实例化
    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();

        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc,) = config.activeNetworkConfig();

        if (block.chainid == 31_337) {
            vm.deal(user, STARTING_USER_BALANCE);
        }
        ERC20Mock(weth).mint(user, STARTING_USER_BALANCE);
        ERC20Mock(wbtc).mint(user, STARTING_USER_BALANCE);

        ERC20Mock(weth).mint(user2, STARTING_USER_BALANCE);
        ERC20Mock(wbtc).mint(user2, STARTING_USER_BALANCE);
    }

    ///////////////////////////////////
    // modifier //
    ///////////////////////////////////

    modifier depositedCollateral() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        uint256 allowance = ERC20Mock(weth).allowance(user, address(dsce));
        dsce.depositCollateral(weth, amountCollateral);
        vm.stopPrank();
        _;
    }

    modifier depositCollateralAndMintDSC() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateralAndMintDSC(weth, amountCollateral, amountToMint);
        vm.stopPrank();
        _;
    }

    modifier liqudateDepositedCollateral() {
        vm.startPrank(user2);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        //100 *150 = 15000
        dsce.depositCollateralAndMintDSC(weth, amountCollateral, amountToMint * 150);
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(2500 * 10 ** 8); // 将ETH价格降低到1000美元
        vm.stopPrank();
        _;
    }

    ///////////////////////
    // Constructor Tests //
    ///////////////////////

    address[] public tokenAddresses;
    address[] public feedAddresses;

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        feedAddresses.push(ethUsdPriceFeed);
        feedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch.selector);
        new DSCEngine(tokenAddresses, feedAddresses, address(dsc));
    }

    function testGetTokenFromUsd() public {
        // If we want $100 of WETH @ $3000/WETH, that would be 0.3 WETH
        uint256 expectedWeth = 1 ether;
        uint256 amountWeth = dsce.getTokenFromUsd(weth, 3000 ether);
        assertEq(amountWeth, expectedWeth);
    }

    //////////////////
    // Price Tests //
    //////////////////

    function testGetUsdValueOfEth() public {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 45_000e18;
        uint256 usdValue = dsce.getUsdValue(weth, ethAmount);
        assertEq(usdValue, expectedUsd);
    }

    ///////////////////////////////////////
    // depositCollateral Tests //
    ///////////////////////////////////////

    function testRevertsIfCollateralZero() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock randToken = new ERC20Mock("RAN", "RAN", user, 100e18);
        vm.startPrank(user);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowToken.selector);
        dsce.depositCollateral(address(randToken), amountCollateral);
        vm.stopPrank();
    }

    function testCanDepositCollateralAndGetAccount() public depositedCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(user);
        uint256 expectedDepositedAmount = dsce.getTokenFromUsd(weth, collateralValueInUsd);

        assertEq(totalDscMinted, 0);
        assertEq(expectedDepositedAmount, amountCollateral);
    }

    ///////////////////////////////////
    // mintDsc Tests //
    ///////////////////////////////////
    function testGetHealthFactor() public {
        uint256 healthFactor = dsce.getHealthFactor(user);

        assertEq(healthFactor, type(uint256).max);
    }

    function testGetHealthFactor_AfterMinting() public {
        uint256 collateralAmount = 100 ether;
        uint256 mintAmount = 50 ether;

        // 为用户存入抵押品并铸造 DSC
        vm.startPrank(user);
        ERC20Mock(weth).mint(user, collateralAmount);
        ERC20Mock(weth).approve(address(dsce), collateralAmount);
        dsce.depositCollateral(weth, collateralAmount);
        dsce.mintDSC(mintAmount);
        vm.stopPrank();

        // 获取健康因子
        uint256 healthFactor = dsce.getHealthFactor(user);

        // 计算预期的健康因子
        (, uint256 collateralValueInUsd) = dsce.getAccountInformation(user);
        uint256 expectedHealthFactor = dsce.getCalculateHealthFactor(mintAmount, collateralValueInUsd);

        // 验证健康因子是否正确
        assertEq(healthFactor, expectedHealthFactor);
    }

    function testMintDsc_HealthFactorOK() public depositedCollateral {
        vm.startPrank(user);

        uint256 mintAmount = 1 ether;
        //Before minted
        (uint256 totalDscMintedBefore, uint256 collateralValueInUsdBefore) = dsce.getAccountInformation(user);

        dsce.mintDSC(mintAmount);

        //After minted
        (uint256 totalDscMintedAfter, uint256 collateralValueInUsdAfter) = dsce.getAccountInformation(user);
        assertEq(totalDscMintedAfter, totalDscMintedBefore + mintAmount);
        assertEq(collateralValueInUsdAfter, collateralValueInUsdBefore);
        vm.stopPrank();
    }

    function testMintDsc_AmountIsZero() public {
        vm.startPrank(user);

        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateralAndMintDSC(weth, amountCollateral, 100);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.mintDSC(0);

        vm.stopPrank();
    }

    function testMintDSC_FailsDueToHealthFactor() public depositedCollateral {
        (, int256 price,,,) = MockV3Aggregator(ethUsdPriceFeed).latestRoundData();
        amountToMint = (amountCollateral * (uint256(price) * dsce.getAdditionalFeedPrecision())) / dsce.getPrecision();
        console.log(amountToMint);

        vm.startPrank(user);
        uint256 expectedHealthFactor =
            dsce.getCalculateHealthFactor(amountToMint, dsce.getUsdValue(weth, amountCollateral));
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, expectedHealthFactor));
        dsce.mintDSC(amountToMint);
        vm.stopPrank();
    }

    ///////////////////////////////////
    // BurnsDsc Tests //
    ///////////////////////////////////
    function testBurnDsc_ZeroAmount() public {
        uint256 burnAmount = 0;

        // 尝试销毁 0 个 DSC
        vm.startPrank(user);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.burnDsc(burnAmount);
        vm.stopPrank();
    }

    function testBurnDsc_MoreThanUser() public depositedCollateral {
        vm.prank(user);
        vm.expectRevert();
        dsce.burnDsc(1);
    }

    function testCanBurnDsc() public depositCollateralAndMintDSC {
        vm.startPrank(user);
        dsc.approve(address(dsce), amountToMint);
        dsce.burnDsc(amountToMint);
        vm.stopPrank();

        uint256 userBalance = dsc.balanceOf(user);
        assertEq(userBalance, 0);
    }

    ///////////////////////////////////
    // redeemCollateral Tests //
    //////////////////////////////////
    function testRedeemCollateralForDSC() public depositCollateralAndMintDSC {
        uint256 amountCollateral = 5 ether;
        uint256 amountDscToBurn = 5 ether;

        uint256 expectedDscBalance = dsce.getDSCMinted(user) - amountDscToBurn;
        uint256 accountCollateralValue = dsce.getAccountCollateralValue(user);
        (, int256 price,,,) = MockV3Aggregator(ethUsdPriceFeed).latestRoundData();
        uint256 amountDscToBurnValue =
            (amountDscToBurn * (uint256(price) * dsce.getAdditionalFeedPrecision())) / dsce.getPrecision();

        vm.startPrank(user);
        dsc.approve(address(dsce), amountDscToBurn);
        dsce.redeemCollateralForDSC(weth, amountCollateral, amountDscToBurn);
        vm.stopPrank();

        assertEq(expectedDscBalance, dsce.getDSCMinted(user));
        assertEq(dsce.getAccountCollateralValue(user), accountCollateralValue - amountDscToBurnValue);
    }

    ///////////////////////////////////
    // Liquidate Tests //
    ///////////////////////////////////
    function testliqudate_healthFactorOK() public depositedCollateral {
        uint256 debtToCover = 1 ether;

        // 获取当前健康因子，确认它是OK的
        uint256 currentHealthFactor = dsce.getHealthFactor(user);
        assert(currentHealthFactor >= dsce.getMIN_HEALTH_FACTOR());

        // 尝试清算，预期应当失败并抛出HealthFactorOK错误
        vm.startPrank(user);
        vm.expectRevert(DSCEngine.HealthFactorOK.selector);
        dsce.liquidate(weth, user, debtToCover);
        vm.stopPrank();
    }

    function testLiquidate_Success() public liqudateDepositedCollateral {
        console.log(dsce.getHealthFactor(user2));

        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), 100 ether);
        dsce.depositCollateralAndMintDSC(weth, 100 ether, 30000 ether);
        vm.stopPrank();

        vm.startPrank(user);
        dsc.approve(address(dsce), 30000 ether);
        dsce.liquidate(weth, user2, 8000 ether); // 清算操作
        console.log(dsce.getHealthFactor(user2));
        assert(dsce.getHealthFactor(user2) >= dsce.getMIN_HEALTH_FACTOR());

        vm.stopPrank();
    }

    // function testLiquidate_SuccessReward() public liqudateDepositedCollateral {
    //     vm.startPrank(user);

    //     // 清算前记录账户状态
    //     uint256 initialWethBalance = ERC20Mock(weth).balanceOf(user);
    //     uint256 initialCollateralValue = dsce.getAccountCollateralValue(user);
    //     console.log("Initial WETH Balance:", initialWethBalance);
    //     console.log("Initial Collateral Value:", initialCollateralValue);

    //     // 进行存款和铸造操作
    //     ERC20Mock(weth).approve(address(dsce), 100 ether);
    //     dsce.depositCollateralAndMintDSC(weth, 100 ether, 5000 ether);

    //     // 再次记录清算前的账户状态
    //     uint256 preLiquidateWethBalance = ERC20Mock(weth).balanceOf(user);
    //     uint256 preLiquidateCollateralValue = dsce.getAccountCollateralValue(user);
    //     console.log("Pre-Liquidate WETH Balance:", preLiquidateWethBalance);
    //     console.log("Pre-Liquidate Collateral Value:", preLiquidateCollateralValue);

    //     vm.stopPrank();

    //     // 进行清算操作
    //     vm.startPrank(user);
    //     dsc.approve(address(dsce), 5000 ether);
    //     dsce.liquidate(weth, user2, 5000 ether);

    //     // 清算后的账户状态
    //     uint256 finalWethBalance = ERC20Mock(weth).balanceOf(user);
    //     uint256 finalCollateralValue = dsce.getAccountCollateralValue(user);
    //     console.log("Final WETH Balance:", finalWethBalance);
    //     console.log("Final Collateral Value:", finalCollateralValue);

    //     vm.stopPrank();

    //     // 计算并验证奖励
    //     // uint256 expectedReward = /* 根据你的清算奖励比例和债务来计算 */;
    //     // uint256 actualReward = finalWethBalance - preLiquidateWethBalance;
    //     // assertEq(actualReward, expectedReward, "清算奖励发放不正确");
    // }

    ////////////////////////////////////////////////////////////////////////////
    // External & Public View & Pure Functions TesT
    ////////////////////////////////////////////////////////////////////////////

    function testgetAccountCollateralValue() public depositedCollateral {
        // 获取用户的抵押品总价值
        uint256 collateralValue = dsce.getAccountCollateralValue(user);

        // 假设 WETH 的价格为 $3000，用户存入了 10 个 WETH
        uint256 ethUsdPrice = 3000 ether; // ETH 价格为 3000 USD
        uint256 expectedCollateralValue = amountCollateral * ethUsdPrice / 1 ether;

        // 检查实际返回的抵押品总价值是否与预期值一致
        assertEq(collateralValue, expectedCollateralValue);
    }

    function testGetAccountInformation() public depositedCollateral {
        // 用户铸造了一定数量的 DSC（假设为 100 ether）
        uint256 mintedDSC = 100 ether;

        vm.startPrank(user);
        dsce.mintDSC(mintedDSC);
        vm.stopPrank();

        // 获取用户的铸造数量和抵押品总价值
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(user);

        // 假设 WETH 的价格为 $3000，用户存入了 10 个 WETH
        uint256 ethUsdPrice = 3000 ether;
        uint256 expectedCollateralValue = amountCollateral * ethUsdPrice / 1 ether;

        // 验证铸造的 DSC 数量和抵押品总价值
        assertEq(totalDscMinted, mintedDSC);
        assertEq(collateralValueInUsd, expectedCollateralValue);
    }
}
