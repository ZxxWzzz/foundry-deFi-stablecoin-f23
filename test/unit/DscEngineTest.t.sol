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
    MockV3Aggregator mkA;

    DecentralizedStableCoin dsc;
    DSCEngine dscEngine;

    address ethUsdPriceFeed;
    address weth;

    // address wbtcUsdPriceFeed;

    //实例化
    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dscEngine, config) = deployer.run();

        // (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc, uint256 deployerKey) =
        //     config.activeNetworkConfig();
        (ethUsdPriceFeed, weth,,,) = config.activeNetworkConfig();
        // mkA = new MockV3Aggregator(8, 3000e8);
    }

    function testGetUsdValueOfEth() public {
        // 获取 ETH/USD 和 WETH 价格
        int256 ethPrice = MockV3Aggregator(ethUsdPriceFeed).latestAnswer();
        int256 wethPrice = MockV3Aggregator(weth).latestAnswer(); // 假设 WETH 也有价格预言机

        // 打印 ETH/USD 价格
        console.log("ETH/USD Price:", uint256(ethPrice));

        // 打印 WETH 价格
        console.log("WETH Price:", uint256(wethPrice));

        // 你可以继续添加其他测试逻辑
        // uint256 ethAmount = 15e18;
        // uint256 expectedUsd = 45_000e18;
        // uint256 usdValue = dscEngine.getUsdValue(weth, ethAmount);
        // assertEq(usdValue, expectedUsd);
    }
}
