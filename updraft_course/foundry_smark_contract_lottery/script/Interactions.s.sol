// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "../lib/chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
// import {LinkToken} from "../test/mocks/LinkToken.sol";
import {CodeConstants} from "./HelperConfig.s.sol";
import {IVRFSubscriptionV2Plus} from "../lib/chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFSubscriptionV2Plus.sol";
import {DevOpsTools} from "../lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();
        return createSubscription(networkConfig.vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator) public returns (uint256, address) {
        vm.startBroadcast(); // 创建时也应该用广播身份，否则后面充值时的身份不同(非owner不能充值)
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        return (subId, vrfCoordinator);
    }

    function run() external returns (uint256, address) {
        vm.startBroadcast();
        (uint256 subId, address coordinator) = createSubscriptionUsingConfig();
        vm.stopBroadcast();
        return (subId, coordinator);
    }
}

contract FundSubscription is Script, CodeConstants {
    uint256 constant FUND_AMOUNT = 0.0001 ether;

    function fundSubscription(uint256 subId, address vrfCoordinator, address /* link */) public {
        // 任何人都可以为 subscription 充值，不需要是 owner
        vm.startBroadcast();
        if (block.chainid == ANVIL_CHAIN_ID) {
            // 本地测试网络mock的base fee是0.25 ether太贵
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subId, FUND_AMOUNT * 10000);
        } else {
            // 最近 faucets LINK 不稳定，只好先用 native token(ETH) 来 fund
            IVRFSubscriptionV2Plus coordinator = IVRFSubscriptionV2Plus(vrfCoordinator);
            coordinator.fundSubscriptionWithNative{value: FUND_AMOUNT}(subId);
        }
        vm.stopBroadcast();
    }

    function run() external {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        fundSubscription(config.subscriptionId, config.vrfCoordinator, config.link);
    }
}

contract AddConsumer is Script, CodeConstants {
    /*
     * 关于 VRF Subscription 的权限控制:
     * 1. 每个 subscription 都有一个所有者(owner)，拥有以下特权:
     *    - 添加/删除消费者(consumers)
     *    - 充值 LINK 代币
     *    - 取出未使用的 LINK 代币
     *    - 转移所有权
     *
     * 2. 权限验证失败的原因:
     *    - subscription owner: 0x28C383FC8666f050A6FDEA1d5d586E814f9DFE8f (从VRF UI创建时使用的钱包地址)
     *    - 当前调用者: 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f (测试用的默认账户)
     *
     * 3. 错误信息 MustBeSubOwner 的含义:
     *    - "必须是subscription的所有者才能执行这个操作"
     *    - 括号中的地址指示谁是实际的所有者
     *    - 这是一个安全检查，确保只有授权账户才能管理subscription
     *
     * 4. 为什么本地测试能通过:
     *    - 本地Anvil链使用模拟的VRFCoordinator
     *    - 模拟合约没有严格的权限检查
     *    - 或者测试账户自动成为了subscription的所有者
     *
     * 5. 解决方案:
     *    - 需要使用正确的私钥(对应地址0x28C383...)来发送交易
     *    - 因为只有这个地址有权限添加消费者
     */
    function addConsumer(uint256 subId, address vrfCoordinator, address consumer) public {
        if (block.chainid == ANVIL_CHAIN_ID) {
            // 在本地测试网络上，使用默认的测试账户
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, consumer);
        } else {
            // 在 Sepolia 上，使用实际的 subscription owner 的私钥
            // PRIVATE_KEY 会自动从 forge script 的 --private-key 参数获取
            // 不需要显式设置环境变量
            uint256 deployerKey = vm.envUint("PRIVATE_KEY");
            vm.startBroadcast(deployerKey);
            IVRFSubscriptionV2Plus(vrfCoordinator).addConsumer(subId, consumer);
        }
        vm.stopBroadcast();
    }

    function run() external {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        // 使用 DevOpsTools 获取最新部署的 Raffle 合约地址
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumer(config.subscriptionId, config.vrfCoordinator, mostRecentlyDeployed);
    }
}
