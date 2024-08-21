// SPDX-License-Identifier: UNLICENSED
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

    uint256 amountCollateral = 10 ether;
    uint256 amountToMint = 100e8;

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

    modifier depositedCollateral() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        uint256 allowance = ERC20Mock(weth).allowance(user, address(dsce));
        dsce.depositCollateral(weth, amountCollateral);
        vm.stopPrank();
        _;
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
}
