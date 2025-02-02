// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {MoodNft} from "../src/MoodNft.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract DeployMoodNft is Script {
    // 如何查看 tokenURI:
    // 1. 使用正确的返回类型格式调用：
    //    cast call --rpc-url http://localhost:8545 DEPLOYED_ADDRESS "tokenURI(uint256)(string)" TOKEN_ID
    // 2. 解码 base64 部分查看 JSON 内容：
    //    上述命令 | tr -d '"' | cut -d',' -f2 | base64 -d
    // 3. 返回的 JSON 包含：
    //    - NFT 元数据（名称、描述、属性等）
    //    - SVG 图像数据（base64 编码）

    function run() external returns (MoodNft) {
        string memory sadSvg = vm.readFile("./img/sad.svg");
        string memory happySvg = vm.readFile("./img/happy.svg");

        vm.startBroadcast(); // 注意下面要存的是svgToImageUri(sadSvg)，而不是sadSvg
        MoodNft moodNft = new MoodNft(svgToImageUri(sadSvg), svgToImageUri(happySvg));
        vm.stopBroadcast();
        return moodNft;
    }

    function svgToImageUri(string memory svg) public pure returns (string memory) {
        return string.concat("data:image/svg+xml;base64,", Base64.encode(abi.encodePacked(svg)));
    }
}
