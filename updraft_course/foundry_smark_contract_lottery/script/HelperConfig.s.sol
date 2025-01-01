// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

abstract contract CodeConstants {
    uint256 public constant DEFAULT_ANVIL_KEY = 1;
    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant ANVIL_CHAIN_ID = 31337;
}

contract HelperConfig is Script, CodeConstants {
    error HelperConfig_ChainIdNotSupported(uint256 chainId);

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address link;
    }

    mapping(uint256 => NetworkConfig) public networkConfig;

    constructor() {
        if (block.chainid == SEPOLIA_CHAIN_ID) {
            networkConfig[block.chainid] = getSepoliaEthConfig();
        } else if (block.chainid == ANVIL_CHAIN_ID) {
            networkConfig[block.chainid] = getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig_ChainIdNotSupported(block.chainid);
        }
    }

    function getConfig() public view returns (NetworkConfig memory config) {
        config = networkConfig[block.chainid];
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entranceFee: 0.01 ether,
                interval: 30, // 30 seconds
                vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625, // Chainlink VRF Coordinator v2.5
                gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c, // 150 gwei Key Hash
                subscriptionId: 9929970782370025809564082213265651764134854626883528169543351404708910376986,
                callbackGasLimit: 500000, // 500,000 gas
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789 // Chainlink LINK token
            });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // 如果已经设置了配置，直接返回
        if (networkConfig[ANVIL_CHAIN_ID].vrfCoordinator != address(0)) {
            return networkConfig[ANVIL_CHAIN_ID];
        }

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock coordinator = new VRFCoordinatorV2_5Mock(
            0.25 ether, // baseFee
            1e9, // gasPrice (1 gwei)
            1e18 // weiPerUnitLink (1 LINK = 1e18 wei)
        );
        LinkToken link = new LinkToken();
        vm.stopBroadcast();

        return
            NetworkConfig({
                entranceFee: 0.01 ether,
                interval: 30, // 30 seconds
                vrfCoordinator: address(coordinator),
                gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c, // anything here works on anvil
                subscriptionId: 0, // 需要用户自己创建和填写
                callbackGasLimit: 500000, // 500,000 gas
                link: address(link)
            });
    }
}
