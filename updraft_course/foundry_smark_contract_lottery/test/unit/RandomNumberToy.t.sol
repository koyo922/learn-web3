// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";

/**
 * @title 随机数生成玩具合约
 * @notice 这个合约用于演示VRFCoordinatorV2_5Mock中的随机数生成过程
 * @dev 在测试环境中，VRFCoordinatorV2_5Mock使用一个确定性的过程来生成"随机"数：
 * 1. requestId从1开始递增。第一次请求时requestId=1
 * 2. 当请求numWords=1个随机数时，使用i=0作为第一个（也是唯一一个）随机数的索引
 * 3. 将requestId和i编码后取哈希，得到确定性的"随机"数
 * 4. 这个过程在测试中是完全可重现的
 * 
 * 完整的数值流程：
 * 1. 输入: requestId=1, i=0
 * 2. 编码: abi.encode(1, 0) = 0x000...0001 000...0000 (两个32字节的数)
 * 3. 哈希: keccak256(编码) = 0xada5013122d395ba3c54772283fb069b10426056ef8ca54750cb9bb552a59e7d
 * 4. 转换: uint256(哈希) = 78541660797044910968829902406342334108369226379826116161446442989268089806461
 * 5. 取模: 78541660797044910968829902406342334108369226379826116161446442989268089806461 % 4 = 1
 */
contract RandomNumberToy is Test {
    /**
     * @notice 演示VRFCoordinatorV2_5Mock的随机数生成过程
     * @dev 这个测试完全模拟了VRFCoordinatorV2_5Mock中的随机数生成：
     * 1. requestRandomWords返回requestId=1（因为s_nextRequestId初始值为1）
     * 2. fulfillRandomWords使用i=0（因为只生成一个随机数）
     * 3. 使用keccak256(abi.encode(1, 0))生成随机数
     * 4. 对4取模得到获胜者索引（因为有4个玩家）
     */
    function testRandomNumberGeneration() public {
        // 步骤1: 设置输入值
        // requestId = 1: 因为是VRFCoordinatorV2_5Mock中第一次请求
        // i = 0: 因为只请求一个随机数，所以是第一个也是唯一一个索引
        uint256 requestId = 1;
        uint256 i = 0;

        // 步骤2: 编码数据
        // 使用abi.encode将两个uint256打包
        // 这会产生一个定长的字节数组，每个uint256占32字节
        // 结果是: 0x000...0001 000...0000 (两个32字节的数)
        bytes memory encoded = abi.encode(requestId, i);
        console.log("Step 1 - Encoded data (hex):");
        emit log_bytes(encoded);

        // 步骤3: 计算keccak256哈希
        // 这个过程是确定性的：相同的输入总是产生相同的哈希值
        // 在测试环境中，这个"随机性"是可预测的
        // 结果是: 0xada5013122d395ba3c54772283fb069b10426056ef8ca54750cb9bb552a59e7d
        bytes32 hashed = keccak256(encoded);
        console.log("Step 2 - Keccak256 hash (hex):");
        emit log_bytes32(hashed);

        // 步骤4: 转换为uint256
        // 将32字节的哈希值解释为一个大整数
        // 这个数字看起来很随机，但对于相同的输入是确定的
        // 结果是: 78541660797044910968829902406342334108369226379826116161446442989268089806461
        uint256 randomNumber = uint256(hashed);
        console.log("Step 3 - Random number (decimal):");
        console.log(randomNumber);

        // 步骤5: 模拟4个玩家的情况，对4取模
        // 在Raffle合约的实际测试中：
        // - 总是有4个玩家参与
        // - 使用相同的随机数生成过程
        // - 所以总是选中索引1的玩家作为获胜者
        // 计算: 78541660797044910968829902406342334108369226379826116161446442989268089806461 % 4 = 1
        uint256 playerCount = 4;
        uint256 winnerIndex = randomNumber % playerCount;
        console.log("Step 4 - Winner index (players: 4):");
        console.log(winnerIndex);

        // 步骤6: 验证结果
        // 因为整个过程是确定性的，我们知道：
        // 78541660797044910968829902406342334108369226379826116161446442989268089806461 % 4 = 1
        assertEq(winnerIndex, 1, "Winner index should be 1");
    }
}
