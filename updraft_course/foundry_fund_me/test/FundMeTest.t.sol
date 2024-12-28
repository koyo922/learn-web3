// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// 跑测试 source ../../.env
// forge coverage -vv --fork-url $RPC_URL_ETH

// 注：测试合约继承了 forge-std/Test.sol 的所有断言函数
// 无需单独导入
import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../src/FundMe.sol";

contract FundMeTest is Test {
    FundMe fundMe;
    // Sepolia ETH/USD Price Feed 地址
    address constant PRICE_FEED_ADDRESS =
        0x694AA1769357215DE4FAC081bf1f309aDC325306;

    function setUp() external {
        fundMe = new FundMe(PRICE_FEED_ADDRESS);
    }

    // 注：
    // 1. MINIMUM_USD 虽是公共变量，但需要用函数方式访问：fundMe.MINIMUM_USD()
    // 2. 因为此测试仅读取状态，所以加上 view 修饰符
    function testMinimumDollarIsFive() public view {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsTestObject() public view {
        assertEq(fundMe.i_owner(), address(this));
    }

    function testPriceFeedVersionIsFour() public view {
        assertEq(fundMe.getVersion(), 4);
    }
}
