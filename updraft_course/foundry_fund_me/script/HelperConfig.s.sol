// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";

contract HelperConfig is Script {
    // 价格精度和初始价格常量
    uint8 public constant DECIMALS = 8;
    int256 public constant INITIAL_PRICE = 2000e8;

    struct NetworkConfig {
        address priceFeed; // ETH/USD price feed address
    }
    NetworkConfig public activeNetworkConfig;
    MockV3Aggregator public mockPriceFeed;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory sepoliaConfig = NetworkConfig({
            priceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306
        });
        return sepoliaConfig;
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // 检查是否已经部署过 Mock
        // 这个检查在实际开发环境中很有用，比如：
        // 1. 在同一个部署脚本中多次调用此函数
        // 2. 在不同合约的部署过程中需要重用同一个 price feed
        // 3. 在升级或维护脚本中避免重复部署
        //
        // 注意：在测试环境中(如 FundMeTest.t.sol)这个检查实际上不起作用
        // 因为：
        // 1. 每个测试函数执行前，setUp() 都会重新执行
        // 2. setUp() 会创建新的 DeployFundMe 和 HelperConfig 实例
        // 3. 这意味着 activeNetworkConfig 总是会被重置为初始状态
        // 4. 所以在测试中，这个地址总是会是0，Mock 总是会重新部署
        if (activeNetworkConfig.priceFeed != address(0)) {
            return activeNetworkConfig;
        }
        vm.startBroadcast();
        mockPriceFeed = new MockV3Aggregator(DECIMALS, INITIAL_PRICE);
        vm.stopBroadcast();
        return NetworkConfig({priceFeed: address(mockPriceFeed)});
    }
}
