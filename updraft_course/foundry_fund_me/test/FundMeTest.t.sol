// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// 跑测试 source ../../.env
// forge coverage -vv --fork-url $RPC_URL_ETH

// 注：测试合约继承了 forge-std/Test.sol 的所有断言函数
// 无需单独导入
import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../src/FundMe.sol";
import {DeployFundMe} from "../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;
    address alice = makeAddr("alice");
    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 constant SEND_VALUE = 0.1 ether;
    uint256 constant GAS_PRICE = 1;

    function setUp() external {
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(alice, STARTING_BALANCE);
    }

    modifier funded() {
        vm.prank(alice);
        fundMe.fund{value: SEND_VALUE}();
        assert(address(fundMe).balance > 0);
        _;
    }

    // 注：
    // 1. MINIMUM_USD 虽是公共变量，但需要用函数方式访问：fundMe.MINIMUM_USD()
    // 2. 因为此测试仅读取状态，所以加上 view 修饰符
    function testMinimumDollarIsFive() public view {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsDeployer() public view {
        // 调用栈可视化：
        // 部署过程：
        // [Foundry Test Runner] ← 使用 anvil 第一个测试地址(0x1804c8AB...)作为发送者
        //         ↓ 调用
        // [FundMeTest.setUp()] ← msg.sender 是 Test Runner 地址
        //         ↓ new
        // [DeployFundMe.run()] ← msg.sender 是 FundMeTest 地址
        //         ↓ vm.startBroadcast() ← 这里开始改变了正常的 msg.sender 传递链
        // [broadcast context start] ← 进入广播上下文
        //     - 此上下文中的所有交易的 msg.sender 都被强制设为广播地址
        //     - 这打破了普通的调用链规则，否则应该是 DeployFundMe 地址
        // [new FundMe()] ← msg.sender 被强制设为广播地址 0x1804c8AB...
        // [broadcast context end]
        //
        // 注：如果不使用 broadcast：
        // - FundMe 构造函数中的 msg.sender 应该是 DeployFundMe 的地址
        // - 这会导致测试失败，因为 i_owner 就不是 Test Runner 地址了
        //
        // 测试上下文：
        // [Foundry Test Runner] ← 仍然使用 anvil 第一个测试地址
        //         ↓ 调用
        // [FundMeTest.testOwnerIsDeployer()] ← msg.sender 是 Test Runner 地址
        //
        // 为什么测试能通过？
        // 1. 部署时：broadcast 强制 FundMe 的 i_owner 设为 anvil 第一个地址
        // 2. 测试时：Test Runner 使用相同的 anvil 第一个地址调用测试
        // 3. 所以 fundMe.i_owner() == msg.sender == 0x1804c8AB...
        // console.log("address(this):", address(this));
        // console.log("msg.sender:", msg.sender);
        // console.log("fundMe.i_owner():", fundMe.i_owner());
        assertEq(fundMe.i_owner(), msg.sender);
    }

    function testPriceFeedVersionIsFour() public view {
        assertEq(fundMe.getVersion(), 4);
    }

    function testFundFailsWIthoutEnoughETH() public {
        vm.expectRevert(); // <- The next line after this one should revert! If not test fails.
        fundMe.fund{value: 0}(); // 显式传入 0 值，预期会 revert
    }

    function testFundUpdatesFundDataStructure() public funded {
        uint256 amountFunded = fundMe.getAddressToAmountFunded(alice);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddsFunderToArrayOfFunders() public funded {
        address funder = fundMe.getFunder(0);
        assertEq(funder, alice);
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.expectRevert();
        vm.prank(alice);
        fundMe.withdraw();
    }

    function testWithdrawFromASingleFunder() public funded {
        // Arrange
        uint256 startingFundMeBalance = address(fundMe).balance;
        uint256 startingOwnerBalance = fundMe.getOwner().balance;

        vm.txGasPrice(GAS_PRICE);
        uint256 gasStart = gasleft();

        // Act
        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        uint256 gasEnd = gasleft();
        uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice;
        console.log("Withdraw consumed: %d gas", gasUsed);

        // Assert
        uint256 endingFundMeBalance = address(fundMe).balance;
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(
            startingFundMeBalance + startingOwnerBalance,
            endingOwnerBalance
        );
    }

    function testWithdrawFromMultipleFunders() public funded {
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;
        for (
            uint160 i = startingFunderIndex;
            i < numberOfFunders + startingFunderIndex;
            i++
        ) {
            // we get hoax from stdcheats
            // prank + deal
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingFundMeBalance = address(fundMe).balance;
        uint256 startingOwnerBalance = fundMe.getOwner().balance;

        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        assert(address(fundMe).balance == 0);
        assert(
            startingFundMeBalance + startingOwnerBalance ==
                fundMe.getOwner().balance
        );
        assert(
            (numberOfFunders + 1) * SEND_VALUE == // +1 是因为 funded modifier 中 alice 已投入一次
                fundMe.getOwner().balance - startingOwnerBalance
        );
    }

    function testWithdrawFromMultipleFundersCheaper() public funded {
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;
        for (
            uint160 i = startingFunderIndex;
            i < numberOfFunders + startingFunderIndex;
            i++
        ) {
            // we get hoax from stdcheats
            // prank + deal
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingFundMeBalance = address(fundMe).balance;
        uint256 startingOwnerBalance = fundMe.getOwner().balance;

        vm.startPrank(fundMe.getOwner());
        fundMe.cheaperWithdraw();
        vm.stopPrank();

        assert(address(fundMe).balance == 0);
        assert(
            startingFundMeBalance + startingOwnerBalance ==
                fundMe.getOwner().balance
        );
        assert(
            (numberOfFunders + 1) * SEND_VALUE ==
                fundMe.getOwner().balance - startingOwnerBalance
        );
    }

    function testPrintStorageData() public view {
        for (uint256 i = 0; i < 3; i++) {
            bytes32 value = vm.load(address(fundMe), bytes32(i));
            console.log("Value at location", i, ":");
            console.logBytes32(value);
        }
        console.log("PriceFeed address:", address(fundMe.getPriceFeed()));
    }
}
