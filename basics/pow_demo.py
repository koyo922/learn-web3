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
        new_block.mine_block("000000")
        self.chain.append(new_block)


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
