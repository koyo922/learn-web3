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
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
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
        if (block.chainid == ANVIL_CHAIN_ID) {
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subId, FUND_AMOUNT);
        } else {
            // 最近 faucets LINK 不稳定，只好先用 native token(ETH) 来 fund
            IVRFSubscriptionV2Plus coordinator = IVRFSubscriptionV2Plus(vrfCoordinator);
            coordinator.fundSubscriptionWithNative{value: FUND_AMOUNT}(subId);
        }
    }

    function run() external {
        vm.startBroadcast();
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        fundSubscription(config.subscriptionId, config.vrfCoordinator, config.link);
        vm.stopBroadcast();
    }
}

contract AddConsumer is Script {
    function addConsumer(uint256 subId, address vrfCoordinator, address consumer) public {
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, consumer);
    }

    function run() external {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        // 使用 DevOpsTools 获取最新部署的 Raffle 合约地址
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        vm.startBroadcast();
        addConsumer(config.subscriptionId, config.vrfCoordinator, mostRecentlyDeployed);
        vm.stopBroadcast();
    }
}
