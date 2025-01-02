// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

abstract contract CodeConstants {
    uint256 public constant DEFAULT_ANVIL_KEY = 1;
    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant ANVIL_CHAIN_ID = 31337;

    uint96 public constant VRF_BASE_FEE = 0.25 ether;
    uint96 public constant VRF_GAS_PRICE = 1e9; // 1 gwei
    int256 public constant VRF_WEI_PER_UNIT_LINK = 1e18; // 1 LINK = 1e18 wei
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
        // https://docs.chain.link/vrf/v2-5/supported-networks#sepolia-testnet
        return
            NetworkConfig({
                entranceFee: 0.01 ether,
                interval: 30, // 30 seconds
                vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B, // Chainlink VRF Coordinator v2.5
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // 150 gwei Key Hash
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
        VRFCoordinatorV2_5Mock coordinator = new VRFCoordinatorV2_5Mock(VRF_BASE_FEE, VRF_GAS_PRICE, VRF_WEI_PER_UNIT_LINK);
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
