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

        // (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc, uint256 deployerKey) =
        //     config.activeNetworkConfig();
        (ethUsdPriceFeed,, weth,,) = config.activeNetworkConfig();
        // mkA = new MockV3Aggregator(8, 3000e8);
    }

    function testGetUsdValueOfEth() public {
        HelperConfig.NetworkConfig memory networkConfig = config.getAnvilNetworkConfig();

        // int256 wbtcPrice = MockV3Aggregator(networkConfig.wbtcUsdPriceFeed).latestAnswer();
        // console.log("WBTC/USD Price:", uint256(wbtcPrice));

        // int256 wethPrice = MockV3Aggregator(networkConfig.wethUsdPriceFeed).latestAnswer();
        // console.log("WETH/USD Price:", uint256(wethPrice));

        // uint256 ethAmount = 15e18;
        // uint256 expectedUsd = 45_000e18;
        // uint256 usdValue = dscEngine.getUsdValue(weth, ethAmount);
        // assertEq(usdValue, expectedUsd);
    }
}
