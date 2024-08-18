// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";

contract DscEngineTest is Test {
    DeployDSC deployer;
    HelperConfig config;

    DecentralizedStableCoin dsc;
    DSCEngine dscEngine;

    address ethUsdPriceFeed;
    address weth;
    address btcUsdPriceFeed;
    address wbtc;

    // address wbtcUsdPriceFeed;

    //实例化
    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dscEngine, config) = deployer.run();

        (ethUsdPriceFeed,, weth,,) = config.activeNetworkConfig();

        // 打印价格以确认映射正确
        MockV3Aggregator ethPriceFeed = MockV3Aggregator(ethUsdPriceFeed);
        int256 ethPrice = ethPriceFeed.latestAnswer();
        console.log("ETH/USD Price in setUp:", uint256(ethPrice));

        // // 类似地检查 BTC 价格
        // MockV3Aggregator btcPriceFeed = MockV3Aggregator(btcUsdPriceFeed);
        // int256 btcPrice = btcPriceFeed.latestAnswer();
        // console.log("BTC/USD Price in setUp:", uint256(btcPrice));
    }

    function testGetUsdValueOfEth() public {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 45_000e18;
        uint256 usdValue = dscEngine.getUsdValue(weth, ethAmount);
        assertEq(usdValue, expectedUsd);
    }
}
