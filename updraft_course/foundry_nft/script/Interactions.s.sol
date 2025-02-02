// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {BasicNft} from "../src/BasicNft.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";

contract MintBasicNft is Script {
    string public constant PUG = "https://ipfs.io/ipfs/QmSsYRx3LpDAb1GZQm7zZ1AuHZjfbPkD6J7s9r41xu1mf8?filename=pug.png";

    function run() external {
        // 通过 FFI 调用系统命令读取 broadcast 目录，获取最近部署的合约地址
        address mostRecentDeployed = DevOpsTools.get_most_recent_deployment("BasicNft", block.chainid);
        mintNtfOnContract(mostRecentDeployed);
    }

    function mintNtfOnContract(address contractAddress) public {
        // 开始广播交易，使用配置的私钥(例如 .env 中的 PRIVATE_KEY)进行签名
        // 私钥对应的地址将成为 msg.sender，即 NFT 接收者
        vm.startBroadcast();
        // 将地址转为 BasicNft 类型，然后调用它的 mintNft 方法
        BasicNft(contractAddress).mintNft(PUG);
        vm.stopBroadcast();
    }
}
