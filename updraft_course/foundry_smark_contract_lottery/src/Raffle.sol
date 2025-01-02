// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {IRaffle} from "./interfaces/IRaffle.sol";

/**
 * @title A sample Raffle Contract
 * @author Patrick Collins (or even better, you own name)
 * @notice This contract is for creating a sample raffle
 * @dev It implements Chainlink VRFv2.5 and Chainlink Automation
 * 
 * @dev 重要的设计原则：
 * 1. 确定性逻辑（如performUpkeep）倾向开放：
 *    - 纯粹基于链上状态的计算
 *    - 任何人都可以验证条件是否满足
 *    - 执行结果是确定的，不依赖外部数据
 *    - 用业务规则约束而不是权限控制
 *    - 符合区块链的透明性和可验证性
 * 
 * 2. 预言机调用（如fulfillRandomWords）需要严格控制：
 *    - 依赖外部数据源
 *    - 必须验证数据提供者的身份
 *    - 数据会影响合约的关键决策（如随机性）
 *    - 需要访问控制来保证数据来源可信
 *    - 防止恶意数据污染系统
 */
contract Raffle is IRaffle, VRFConsumerBaseV2Plus {
    error Raffle_NotEnoughEthSent();
    error Raffle_TransferFailed();
    error Raffle_RaffleNotOpen();
    error Raffle_UpkeepNotNeeded(uint256 balance, uint256 playersLength, uint256 raffleState);

    enum RaffleState {
        OPEN,
        CALCULATING
    }

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    // 抽奖间隔时间
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address payable private s_recentWinner;
    RaffleState private s_raffleState;

    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    // external 比 public 更便宜
    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) revert Raffle_NotEnoughEthSent();
        if (s_raffleState != RaffleState.OPEN) revert Raffle_RaffleNotOpen();
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    function checkUpkeep(bytes memory /* checkData */) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (timeHasPassed && isOpen && hasPlayers && hasBalance);
        return (upkeepNeeded, "");
    }

    /**
     * @notice 执行抽奖开奖
     * @dev 这个函数是 external 的，任何人都可以调用，但这是安全的，原因如下：
     * 
     * 1. 严格的检查机制：
     *    - 必须通过 checkUpkeep 的所有条件
     *    - 时间间隔已到
     *    - 状态为 OPEN
     *    - 有玩家参与
     *    - 合约有余额
     *    - 如果条件不满足，交易会被 revert
     * 
     * 2. 即使被恶意调用也是安全的：
     *    - 不会造成资金损失
     *    - 不会影响随机性（由 VRF 保证）
     *    - 不会打乱游戏逻辑
     *    - 最多只是提前触发了"本来就该发生的开奖"
     *    - 恶意用户还需支付 gas 费
     * 
     * 3. 访问控制设计上的区别：
     *    - VRF回调必须验证调用者身份，因为随机数直接影响游戏公平性
     *    - 而本函数只是执行既定规则，不会影响游戏公平性
     *    - 所以这里用业务逻辑约束更符合区块链的开放性理念
     *    - 合约的安全性来自于逻辑约束，而不是人为的访问控制
     */
    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) revert Raffle_UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash, // relate to gas price
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit, // gas limit
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );
        emit RequestedRaffleWinner(requestId); // 其实这里没必要，因为requestRandomWords会emit类似的事件
    }

    /**
     * @dev 这个函数由 VRF Coordinator 调用来提供随机数
     * @dev 在测试环境中，VRFCoordinatorV2_5Mock使用一个确定性的过程来生成"随机"数：
     * @dev 1. requestId从1开始递增。第一次请求时requestId=1
     * @dev 2. 当请求numWords=1个随机数时，使用i=0作为第一个（也是唯一一个）随机数的索引
     * @dev 3. 将requestId和i编码后取哈希，得到确定性的"随机"数
     * @dev 4. 这个过程在测试中是完全可重现的
     * @dev 具体过程可以参考test/unit/RandomNumberToy.t.sol中的演示
     * @dev 注意：这只是测试环境的行为。在真实网络中，Chainlink VRF 提供真正的随机数
     */
    function fulfillRandomWords(uint256 /* requestId */, uint256[] calldata randomWords) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];

        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;
        // 在Solidity中，数组没有类似Python的.clear()方法
        // 因为Solidity是在EVM上运行，没有自动垃圾回收机制
        // 这里通过创建新的空数组来重置s_players，旧数组会被标记为未使用并释放存储空间
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(winner);

        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) revert Raffle_TransferFailed();
    }

    /** Getter Function */

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 index) external view returns (address) {
        return s_players[index];
    }

    function getPlayers() public view returns (address payable[] memory) {
        return s_players;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }
}
