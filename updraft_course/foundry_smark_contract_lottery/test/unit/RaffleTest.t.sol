// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {CodeConstants} from "../../script/HelperConfig.s.sol";
import {IRaffle} from "../../src/interfaces/IRaffle.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

contract RaffleTest is Test, IRaffle, CodeConstants {
    Raffle raffle;
    HelperConfig helperConfig;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        HelperConfig.NetworkConfig memory cfg = helperConfig.getConfig();
        entranceFee = cfg.entranceFee;
        interval = cfg.interval;
        vrfCoordinator = cfg.vrfCoordinator;
        gasLane = cfg.gasLane;
        subscriptionId = cfg.subscriptionId;
        callbackGasLimit = cfg.callbackGasLimit;

        // 注意：在 Sepolia fork 上测试时，合约会显示 0.101 ETH 的初始余额
        // 这是因为我们 fork 了主网状态，此时的 Raffle 合约地址上可能已经存在之前测试遗留的 ETH
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testRaffleIsInitializedInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWhenYouDontPayEnough() public {
        // Arrange
        vm.prank(PLAYER);
        // Act/Assert
        vm.expectRevert(Raffle.Raffle_NotEnoughEthSent.selector);
        raffle.enterRaffle{value: entranceFee - 1}();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        assert(raffle.getPlayer(0) == PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public {
        // 1. 设置测试场景：将下一个msg.sender设置为PLAYER
        vm.prank(PLAYER);

        // vm.expectEmit 像掩码一样工作，用true/false选择要比较的事件字段:
        // 对于事件 EnteredRaffle(address indexed player):
        // - param1(true):  [✓] 比较第一个topic(player地址)
        // - param2(false): [x] 忽略第二个topic(没有)
        // - param3(false): [x] 忽略第三个topic(没有)
        // - param4(false): [x] 忽略非indexed字段(没有)
        // - param5(address(raffle)): 事件来源地址，因为链上可能有多个合约发出相同结构的事件，我们只验证raffle合约的事件
        //
        // 特殊用例: 如果全部设为false，则只检查事件类型，忽略所有参数值:
        // vm.expectEmit(false, false, false, false, address(raffle));
        // emit EnteredRaffle(anyValue);  // 只要是EnteredRaffle事件就通过

        // 如果要验证多个事件，需要按顺序多次调用vm.expectEmit，例如:
        // vm.expectEmit(true, false, false, false, address(raffle));
        // emit Event1(param1);  // 期望第一个事件
        // vm.expectEmit(true, false, false, false, address(raffle));
        // emit Event2(param2);  // 期望第二个事件
        // contract.doSomething();  // 实际调用，应该按顺序发出Event1和Event2

        vm.expectEmit(true, false, false, false, address(raffle));

        // 3. 定义期望的事件
        // 这里我们继承了IRaffle接口，所以可以直接使用EnteredRaffle事件
        // 在Python中，这类似于:
        // self.assertEmitted(raffle.EnteredRaffle, {"player": PLAYER})
        emit EnteredRaffle(PLAYER);

        // 4. 触发实际的事件
        // 调用enterRaffle会发出EnteredRaffle事件
        // Foundry会自动比较实际发出的事件与我们在上面定义的期望事件
        raffle.enterRaffle{value: entranceFee}();
    }

    function testPlayerCanNotEnterWhileRaffleIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        // 模拟时间流逝，将区块时间戳增加interval+1秒
        // 这样可以确保checkUpkeep()中的timeHasPassed条件为true
        vm.warp(block.timestamp + interval + 1);
        // 模拟区块高度增加，通常与warp一起使用以保持一致性
        // 因为在实际链上，新区块会同时更新时间戳和区块高度
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle_RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    /*/////////////////////////////////////////////////////////////////////////
                                   CHECK UPKEEP
    //////////////////////////////////////////////////////////////////////// */

    function testCheckUpkeepReturnsFalseIfNoBalance() public {
        vm.prank(PLAYER);
        // raffle.enterRaffle{value: entranceFee}();
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testChechUpkeepReturnsFalseIfRaffleIsNotOpen() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfNotEnoughTimeHasPassed() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval - 1);
        vm.roll(block.number + 1);
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueIfParamsAreCorrect() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(upkeepNeeded);
    }

    /*/////////////////////////////////////////////////////////////////////////
                                  PERFORM UPKEEP
    //////////////////////////////////////////////////////////////////////// */
    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public raffleEntered {
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        uint256 currentBalance = address(raffle).balance;
        uint256 playersLength = raffle.getPlayers().length;
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        // upkeep 不被需要的原因:
        // 1. hasPlayers = false (当前没有玩家参与)
        // 2. timeHasPassed = false (时间间隔未到)
        // 3. isOpen = true (已满足)
        // 4. hasBalance = true (已满足，当前余额: 0.101 ETH)
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle_UpkeepNotNeeded.selector, currentBalance, playersLength, raffleState));
        raffle.performUpkeep("");
    }

    function testPerformUpkeepEmitsRequestedRaffleWinnerEvent() public raffleEntered {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        assert(requestId > 0);
        assert(raffle.getRaffleState() == Raffle.RaffleState.CALCULATING);
    }

    /*/////////////////////////////////////////////////////////////////////////
                            FULFILL RANDOM WORDS
    //////////////////////////////////////////////////////////////////////// */

    modifier skipOnSepoliaFork() {
        if (block.chainid != ANVIL_CHAIN_ID) {
            return;
        }
        _;
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId) public raffleEntered skipOnSepoliaFork {
        // 在本地网络上，直接调用 fulfillRandomWords
        // Mock网络里面anyone都可以调用fulfillRandomWords，实际网络里面只有VRF Node可以调用
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    // test whole process or enter,pick winner,fulfill random words, send prize
    function testEntireRaffleProcessIsFunctional() public raffleEntered {
        // 注意：在 Sepolia fork 上测试时，合约会有初始余额（约0.101 ETH）+ raffleEntered()导致的第零个PLAYER入场费
        // 这是因为我们 fork 了主网状态，此时的 Raffle 合约地址上可能已经存在之前测试遗留的 ETH
        // 所以在计算最终奖金时，需要使用合约的实际余额，而不是简单地用 entranceFee * players.length
        // 而在anvil情况下，合约在此处的初始余额就只有第零个PLAYER的入场费
        uint256 initialBalance = address(raffle).balance;

        // Arrange: 3 additional entries
        uint256 additionalEntries = 3;
        for (uint256 i = 1; i < 1 + additionalEntries; i++) {
            address player = address(uint160(i));
            hoax(player, 1 ether);
            raffle.enterRaffle{value: entranceFee}();
        }
        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        address expectedWinner = address(1);
        uint256 winnerStartingBalance = expectedWinner.balance;

        // Act: perform upkeep & fulfill random words
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        uint256 chainId;
        assembly {
            chainId := chainid()
        }

        if (chainId == ANVIL_CHAIN_ID) {
            // 在本地网络上，直接调用 fulfillRandomWords
            VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));
        } else {
            // 在 Sepolia fork 上，我们需要模拟 VRF Coordinator 的行为
            // 准备随机数数组
            uint256[] memory randomWords = new uint256[](1);
            randomWords[0] = 5; // 5 % 4 = 1，确保在任何环境下都选中 address(1)

            // 模拟 VRF Coordinator 的回调
            vm.prank(vrfCoordinator);
            VRFConsumerBaseV2Plus(address(raffle)).rawFulfillRandomWords(uint256(requestId), randomWords);
        }

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();

        // 使用合约的最终余额作为奖金
        // 第零个PLAYER的入场费已经在initialBalance中计算过了, 这里不需要 entranceFee + 1
        uint256 prize = initialBalance + additionalEntries * entranceFee; // 0.141 ETH = 初始余额(0.111) + 3个玩家的入场费(0.03)

        assert(recentWinner == expectedWinner); // 在任何环境下，随机数5都应该选中 address(1)
        assert(raffleState == Raffle.RaffleState.OPEN);
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
