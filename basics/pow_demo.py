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
        while self.hash[:len(target_prefix)] != target_prefix:
            self.nonce += 1
            self.hash = self.calculate_hash()
        print(f"Block mined: {self.hash}")


class Blockchain:
    """区块链结构
    在分布式系统中：
    - 每个节点都维护完整的区块链副本
    - 通过共识机制确保网络中的区块链一致性
    """

    def __init__(self):
        self.chain = [self.create_genesis_block()]

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
        new_block.mine_block("0000")  # 改为4个0
        self.chain.append(new_block)


class MinerNode:
    """矿工节点行为模拟"""

    def __init__(self):
        self.blockchain = Blockchain()
        self.is_mining = True  # 控制挖矿循环

    def collect_transactions(self) -> str:
        # 模拟从交易池收集交易
        return f"Transaction batch {datetime.datetime.now()}"

    def broadcast_block(self, block: Block) -> None:
        # 模拟向网络广播新区块
        print(f"Broadcasting new block with hash: {block.hash}")

    def start_mining(self, num_blocks: int = 3) -> None:
        # 持续挖矿过程
        blocks_mined = 0
        while blocks_mined < num_blocks:  # 在实际网络中这是无限循环
            print(f"\nMiner: Starting to mine block #{blocks_mined + 1}")
            transactions = self.collect_transactions()
            new_block = Block(data=transactions)

            self.blockchain.add_block(new_block)  # 包含耗时的挖矿过程
            self.broadcast_block(new_block)

            blocks_mined += 1
            print(f"Miner: Total blocks mined: {blocks_mined}")


class ValidatorNode:
    """验证节点行为模拟"""

    def __init__(self):
        self.blockchain = Blockchain()
        self.is_validating = True  # 控制验证循环

    def receive_blocks(self, num_blocks: int) -> list[Block]:
        # 模拟从网络接收多个区块
        return [Block(f"Received transaction data {i+1}") for i in range(num_blocks)]

    def verify_block(self, block: Block) -> bool:
        # 验证区块的有效性
        target_prefix = "0000"
        is_pow_valid = block.hash.startswith(target_prefix)
        print(f"Validator: Verifying block {block.hash}")
        return is_pow_valid

    def start_validating(self, num_blocks: int = 3) -> None:
        # 持续验证过程
        print("\nValidator: Starting validation process")
        blocks_validated = 0

        # 在实际网络中这是无限循环，监听新区块
        received_blocks = self.receive_blocks(num_blocks)
        for block in received_blocks:
            print(f"\nValidator: Processing block #{blocks_validated + 1}")
            if self.verify_block(block):
                print("Validator: Block verified, adding to chain")
                self.blockchain.chain.append(block)
                blocks_validated += 1
            else:
                print("Validator: Invalid block rejected")

        print(f"Validator: Total blocks validated: {blocks_validated}")


if __name__ == "__main__":
    # 演示代码
    # 注意：实际的区块链网络还需要：
    # 1. P2P网络通信
    # 2. 共识机制(处理分叉)
    # 3. 交易池管理
    # 4. 完整的区块验证规则
    # 5. 挖矿奖励机制
    blockchain = Blockchain()
    blockchain.add_block(Block(data="Block 1"))
    blockchain.add_block(Block(data="Block 2"))
    blockchain.add_block(Block(data="Block 3"))

    # 添加角色模拟演示
    print("\n=== Simulating Different Node Roles ===")

    # 模拟矿工行为
    print("\nMiner Node Simulation:")
    miner = MinerNode()
    miner.mine_new_block()

    # 模拟验证节点行为
    print("\nValidator Node Simulation:")
    validator = ValidatorNode()
    validator.validate_new_block()

    print("\n=== Simulating Continuous Mining and Validation ===")

    # 模拟持续挖矿
    print("\nContinuous Miner Simulation:")
    miner = MinerNode()
    miner.start_mining(num_blocks=3)  # 挖3个区块

    # 模拟持续验证
    print("\nContinuous Validator Simulation:")
    validator = ValidatorNode()
    validator.start_validating(num_blocks=3)  # 验证3个区块
