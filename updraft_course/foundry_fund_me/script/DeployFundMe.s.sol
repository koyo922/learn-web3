// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {FundMe} from "../src/FundMe.sol";
import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployFundMe is Script {
    function run() external returns (FundMe) {
        // 在广播前，获取配置
        HelperConfig helperConfig = new HelperConfig();

        // 使用解构赋值获取配置：
        // 1. activeNetworkConfig() 返回一个 NetworkConfig 结构体
        // 2. 结构体中只有一个 priceFeed 字段
        // 3. 使用 (address priceFeed) 来解构获取这个值
        //
        // 注：Solidity 的结构体 vs Python 的对象
        // - Python 中的对象是动态的，可以有方法，支持链式调用
        //   obj.method1().method2().attribute
        // - Solidity 的结构体是静态的值类型，类似 C 的 struct
        //   - 只是字段的集合，不能有方法
        //   - getter 函数返回的是值的副本，不是引用
        //   - 不能在返回值上继续调用（像 Python 那样）
        //
        // 注：为什么不能用链式调用？
        // - 在 Python 中可以写成: helperConfig.activeNetworkConfig().priceFeed
        // - 但在 Solidity 中，public 变量的自动 getter 函数直接返回整个结构体
        // - 不能在返回的结构体上直接访问字段（不支持链式调用）
        // - 所以需要先获取结构体，再访问其字段
        address priceFeed = helperConfig.activeNetworkConfig();

        vm.startBroadcast();
        FundMe fundMe = new FundMe(priceFeed);
        vm.stopBroadcast();
        return fundMe;
    }
}
