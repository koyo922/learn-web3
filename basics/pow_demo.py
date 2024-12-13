#!/usr/bin/env python3
# ref https://www.geeksforgeeks.org/implementing-the-proof-of-work-algorithm-in-python-for-blockchain-mining/

import hashlib
import datetime
from typing import Any


class Block:
    """区块结构
    在分布式系统中：
    - 矿工负责创建新区块并填充交易数据
    - 所有节点都会验证区块的有效性
    """

    def __init__(self, data, previous_hash=''):
        # 由矿工节点执行：
        # - 收集一段时间内(约10分钟)的交易
        # - 将交易打包成区块
        self.data = data  # the transaction records during a 10min interval
        self.previous_hash = previous_hash  # optional, as will be overwritten in Blockchain.add_block()
        self.timestamp = datetime.datetime.now()
        self.nonce = 0
        self.difficulty = "0000"  # 每个区块都存储当时的难度值
        self.hash = self.calculate_hash()

    def calculate_hash(self):
        # 由所有节点执行：
        # 1. 矿工在挖矿过程中反复计算哈希
        # 2. 其他节点在验证区块时计算一次
        sha = hashlib.sha256()
        sha.update(
            str(self.data).encode()
            + str(self.previous_hash).encode()
            # + str(self.timestamp).encode()
            + str(self.nonce).encode()
        )
        return sha.hexdigest()

    def mine_block(self, target_prefix: str):
        # 仅由矿工节点执行：
        # - 这是最耗费算力的PoW过程
        # - 全网矿工竞争，谁先找到有效nonce谁就获得记账权
        # - 目标前缀越长，难度越大
        self.difficulty = target_prefix  # 保存挖矿时的难度值
        while self.hash[:len(target_prefix)] != target_prefix:
            self.nonce += 1
            self.hash = self.calculate_hash()
        print(f"Block mined with difficulty {len(target_prefix)}: {self.hash}")


class Blockchain:
    """区块链结构
    在分布式系统中：
    - 每个节点都维护完整的区块链副本
    - 通过共识机制确保网络中的区块链一致性
    """

    def __init__(self):
        self.chain = [self.create_genesis_block()]
        self.difficulty = "0000"  # 当前网络难度
        self.target_block_time = 1  # 目标出块时间(秒)
        self.difficulty_adjustment_interval = 4  # 每4个区块调整一次难度

    def adjust_difficulty(self):
        """
        难度调整算法(简化版)：
        - 如果��块太快，增加难度
        - 如果出块太慢，降低难度
        """
        if len(self.chain) % self.difficulty_adjustment_interval != 0:
            return self.difficulty

        # 计算最近10个区块的平均出块时间
        recent_blocks = self.chain[-self.difficulty_adjustment_interval:]
        time_diff = recent_blocks[-1].timestamp - recent_blocks[0].timestamp
        avg_block_time = time_diff / self.difficulty_adjustment_interval

        # 根据平均出块时间调整难度
        if avg_block_time < self.target_block_time:
            return "0" + self.difficulty  # 增加难度
        elif avg_block_time > self.target_block_time:
            return self.difficulty[1:]  # 降低难度
        return self.difficulty

    def create_genesis_block(self):
        # 创世区块：
        # - 网络初始化时只执行一次
        # - 参数在实际网络中是硬编码的
        # - 所有节点都认可同一个创世区块
        return Block("Genesis Block", "0")

    def add_block(self, new_block: Block):
        # 由所有节点执行：
        # 1. 矿工在找到有效区块后广播给网络
        # 2. 其他节点验证后将区块添加到自己的本地链上
        new_block.previous_hash = self.chain[-1].hash
        self.difficulty = self.adjust_difficulty()  # 调整难度
        new_block.mine_block(self.difficulty)
        self.chain.append(new_block)

    def get_latest_difficulty(self) -> str:
        """从最新区块获取当前网络难度"""
        return self.chain[-1].difficulty


class Node:
    """模拟网络节点的基类"""

    def __init__(self):
        self.blockchain = Blockchain()
        self.fork_chains: list[list[Block]] = []  # 存储临时分叉链

    def sync_with_network(self, peer_blocks: list[Block]) -> None:
        temp_chain = []

        for block in peer_blocks:
            if self.verify_block(block, block.difficulty):
                temp_chain.append(block)
            else:
                # 无效区块时,保存当前临时链
                if temp_chain:
                    self.fork_chains.append(temp_chain)
                temp_chain = []  # 重新开始收集
                continue

        # 同步结束后选择最长的有效链
        if temp_chain:
            self.fork_chains.append(temp_chain)

        if self.fork_chains:
            longest_chain = max(self.fork_chains, key=len)
            if len(longest_chain) > len(self.blockchain.chain):
                self.blockchain.chain = longest_chain

    def verify_block(self, block: Block, claimed_difficulty: str) -> bool:
        """验证区块
        1. 验证难度值是否符合网络规则
        2. 验证区块哈希是否满足难度要求
        """
        # 1. 计算这个区块应该使用的难度值
        expected_difficulty = self.calculate_expected_difficulty(block)

        # 2. 验证声称的难度值是否符合预期
        if claimed_difficulty != expected_difficulty:
            print(f"Invalid difficulty: expected {expected_difficulty}, got {claimed_difficulty}")
            return False

        # 3. 验证区块哈希是否满足难度要求
        return block.hash.startswith(claimed_difficulty)

    def calculate_expected_difficulty(self, block: Block) -> str:
        """根据区块高度和时间戳计算期望的难度值"""
        # 获取上一个难度调整点的区块
        adjustment_block = self.get_last_adjustment_block()

        # 如果还没到调整点，使用之前的难度
        if not self.is_adjustment_point(block):
            return adjustment_block.difficulty

        # 如果是调整点，计算新难度
        return self.calculate_new_difficulty(adjustment_block, block)

    def get_last_adjustment_block(self) -> Block:
        """获取上一个难度调整点的区块"""
        for block in reversed(self.blockchain.chain):
            if block.difficulty != "0000":
                return block
        return self.blockchain.chain[0]

    def is_adjustment_point(self, block: Block) -> bool:
        """判断区块是否为难度调整点"""
        return len(self.blockchain.chain) % self.blockchain.difficulty_adjustment_interval == 0

    def calculate_new_difficulty(self, adjustment_block: Block, block: Block) -> str:
        """计算新难度值"""
        # 计算出块时间差
        time_diff = block.timestamp - adjustment_block.timestamp
        avg_block_time = time_diff / (len(self.blockchain.chain) - self.blockchain.chain.index(adjustment_block))

        # 计算新难度
        if avg_block_time < self.blockchain.target_block_time:
            return "0" + adjustment_block.difficulty
        elif avg_block_time > self.blockchain.target_block_time:
            return adjustment_block.difficulty[1:]
        return adjustment_block.difficulty


class MinerNode(Node):
    def __init__(self):
        super().__init__()
        self.is_mining = True

    def start_mining(self, num_blocks: int = 3) -> list[Block]:
        mined_blocks = []
        blocks_mined = 0

        while blocks_mined < num_blocks:
            # 使用 Node 类的难度计算逻辑
            current_difficulty = self.calculate_expected_difficulty(self.blockchain.chain[-1])

            new_block = Block(f"Block {blocks_mined + 1}")
            new_block.previous_hash = self.blockchain.chain[-1].hash
            new_block.mine_block(current_difficulty)

            self.blockchain.chain.append(new_block)
            mined_blocks.append(new_block)
            blocks_mined += 1

        return mined_blocks


class ValidatorNode(Node):
    def start_validating(self, received_blocks: list[Block]) -> None:
        print("\nValidator: Starting validation process")
        self.sync_with_network(received_blocks)
        print(f"Validator: Finished processing {len(received_blocks)} blocks")


if __name__ == "__main__":
    print("=== Simulating Blockchain Network with Difficulty Sync ===")

    # 1. 矿工挖出新区块
    miner = MinerNode()
    new_blocks = miner.start_mining(num_blocks=3)

    # 2. 验证节点同步这些区块
    validator = ValidatorNode()
    validator.start_validating(new_blocks)
