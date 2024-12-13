#!/usr/bin/env python3
# ref https://www.geeksforgeeks.org/implementing-the-proof-of-work-algorithm-in-python-for-blockchain-mining/

import hashlib
import datetime
import random


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
            + str(self.timestamp).encode()
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


# 创世区块应该是硬编码的，而非每个node自己创建(timestamp不一致会有问题)
genesis_block = Block("Genesis Block", "0")


class Blockchain:
    """区块链结构
    在分布式系统中：
    - 每个节点都维护完整的区块链副本
    - 通过共识机制确保网络中的区块链一致性
    """

    def __init__(self):
        self.chain = [genesis_block]
        self.difficulty = "0000"  # 当前网络难度
        self.target_block_time = 1  # 目标出块时间(秒)
        self.difficulty_adjustment_interval = 4  # 每4个区块调整一次难度


class Node:
    """模拟网络节点的基类"""

    def __init__(self):
        self.blockchain = Blockchain()
        self.orphan_blocks: dict[str, Block] = {}  # hash -> block
        self.fork_chains: list[list[Block]] = []

    def process_new_block(self, block: Block) -> None:
        """处理新区块，包括分叉处理

        分叉场景示例:
        时间轴:
        t1: 矿工A和B都在挖Block#100
        t2: 矿工A找到解决方案，广播Block#100-A
        t3: 在收到A的广播之前，矿工B也找到解决方案，广播Block#100-B

        结果:
        Block#99 --> Block#100-A --> Block#101 --> Block#102  (最终胜出的链)
                \-> Block#100-B                               (被抛弃的链)

        安全风险:
        如果某个矿工拥有超级算力(>50%全网算力)：
        1. 可以在Block#100-B后快速挖出更多区块
        2. 形成更长的链并最终被网络接受
        3. 这就是著名的"51%攻击"，可以用来：
           - 回滚已确认的交易
           - 进行双重支付
           - 拒绝打包特定交易

        这就是为什么：
        1. 比特币要等待6个确认才认为交易最终确认
           - 每个确认是指交易所在区块之后的新区块
           - 6个确认约需1小时(每个区块10分钟)
           - 6个确认使得攻击者重组链的概率极低
        2. 去中心化(算力分散)对网络安全至关重要
        """
        # 1. 先验证区块本身是否有效
        if not self.verify_block(block):
            print(f"Invalid block rejected: {block.hash[:10]}...")
            return

        # 2. 检查主链上是否已经有这个区块
        if block.hash in [b.hash for b in self.blockchain.chain]:
            print(f"Duplicate block ignored: {block.hash[:10]}...")
            return

        # 3. 检查在主链上是否有父区块
        parent_in_main = False
        for i, b in enumerate(self.blockchain.chain):
            if b.hash == block.previous_hash:
                parent_in_main = True
                if i == len(self.blockchain.chain) - 1:
                    # 父区块是主链最后一个，直接添加到主链
                    self.blockchain.chain.append(block)
                    print(f"Block added to main chain: {block.hash[:10]}...")
                else:
                    # 创建新的分叉链
                    new_fork = self.blockchain.chain[:i + 1] + [block]
                    self.fork_chains.append(new_fork)
                    print(f"New fork chain created at height {i}")
                self.try_connect_orphans(block.hash)
                return

        # 4. 如果主链上没找到，检查所有分叉链
        for fork_chain in self.fork_chains:
            if block.previous_hash == fork_chain[-1].hash:
                fork_chain.append(block)
                print(f"Block added to fork chain: {block.hash[:10]}...")
                self.try_connect_orphans(block.hash)
                return

        # 5. 如果还是找不到父区块，才放入孤块池
        if block.hash not in self.orphan_blocks:  # 避免重复添加
            self.orphan_blocks[block.hash] = block
            print(f"Orphan block stored: {block.hash[:10]}...")

    def try_connect_orphans(self, parent_hash: str) -> None:
        # 尝试连接依赖这个区块的孤块
        connected = []
        to_delete = []  # 记录需要删除的恶意/无效区块

        for orphan_hash, orphan_block in self.orphan_blocks.items():
            if orphan_block.previous_hash == parent_hash:
                if self.verify_block(orphan_block):
                    self.blockchain.chain.append(orphan_block)
                    connected.append(orphan_hash)
                    # 递归处理
                    self.try_connect_orphans(orphan_block.hash)
                else:
                    print(f"Malicious/invalid orphan block detected and removed: {orphan_hash[:10]}...")
                    to_delete.append(orphan_hash)

        # 移除已连接的有效区块和无效区块
        for hash in connected + to_delete:
            del self.orphan_blocks[hash]

    def sync_with_network(self, peer_blocks: list[Block]) -> None:
        print("\nNode: Starting blockchain sync...")

        # 先处理所有区块，可能都会进入孤块池
        for block in peer_blocks:
            self.process_new_block(block)

        # 循环尝试连接孤块，直到没有新增连接
        while True:
            initial_orphan_count = len(self.orphan_blocks)

            chain_tips = [self.blockchain.chain[-1].hash] + [fork[-1].hash for fork in self.fork_chains]

            # 尝试连接孤块到链末端
            for orphan in list(self.orphan_blocks.values()):
                if orphan.previous_hash in chain_tips:
                    self.process_new_block(orphan)

            # 如果这轮没有新的连接，就退出
            if len(self.orphan_blocks) == initial_orphan_count:
                break

        # 同步完成后，选择最长的有效链
        if self.fork_chains:
            longest_chain = max(self.fork_chains, key=len)
            if len(longest_chain) > len(self.blockchain.chain):
                self.blockchain.chain = longest_chain
                print(f"Switched to longer chain with length {len(longest_chain)}")

        print(f"Sync finished. Chain length: {len(self.blockchain.chain)}, Remaining orphans: {len(self.orphan_blocks)}")

    def verify_block(self, block: Block) -> bool:
        """验证区块
        1. 验证难度值是否符合网络规则
        2. 验证区块哈希是否满足难度要求
        """
        # 验证难度值
        expected_difficulty = self.calculate_expected_difficulty(block)
        if block.difficulty != expected_difficulty:
            print(f"Invalid difficulty: expected {expected_difficulty}, got {block.difficulty}")
            return False

        # 验证哈希
        return block.hash.startswith(block.difficulty)

    def calculate_expected_difficulty(self, block: Block) -> str:
        """根据区块高度和时间戳计算期望的难度值"""
        # 创世区块特殊处理
        if block.previous_hash == "0":
            return block.difficulty  # 使用区块自带的难度值，而不是链上的当前难度

        # 1. 找到区块所在的链和父区块
        chain = self.blockchain.chain
        parent_found = False

        # 在主链上找
        for b in self.blockchain.chain:
            if b.hash == block.previous_hash:
                parent_found = True
                break

        # 如果主链上没找到，在分叉链上找
        if not parent_found:
            for fork in self.fork_chains:
                if block.previous_hash in [b.hash for b in fork]:
                    chain = fork
                    parent_found = True
                    break

        # 如果找不到父区块，暂时信任区块自带的难度值
        if not parent_found:
            return block.difficulty

        # 2. 获取上一个难度调整点的区块
        adjustment_block = self.get_last_adjustment_block(chain)

        # 3. 如果还没到调整点，使用之前的难度
        if not self.is_adjustment_point(block, chain):
            return adjustment_block.difficulty

        # 4. 如果是调整点，计算新难度
        return self.calculate_new_difficulty(adjustment_block, block, chain)

    def get_last_adjustment_block(self, chain: list[Block]) -> Block:
        """获取指定链上最近的难度调整点区块"""
        # 从后往前找到最近的调整点
        current_height = len(chain)
        # 找到最近的调整点高度
        last_adjustment_height = current_height - (current_height % self.blockchain.difficulty_adjustment_interval)

        if last_adjustment_height == 0:
            return chain[0]  # 如果还没到第一个调整点，返回创世区块

        return chain[last_adjustment_height - 1]  # -1因为height从1开始而索引从0开始

    def is_adjustment_point(self, block: Block, chain: list[Block]) -> bool:
        """判断区块是否为难度调整点
        需要考虑区块可能在主链或分叉链上的情况
        """
        # 创世区块特殊处理
        if block.previous_hash == "0":
            return False

        # 先在主链上查找父区块
        block_height = 0
        for b in chain:
            if b.hash == block.previous_hash:
                block_height = chain.index(b) + 2
                break

        # 如果不在主链上，检查分叉链
        if block_height == 0:
            for fork_chain in self.fork_chains:
                for b in fork_chain:
                    if b.hash == block.previous_hash:
                        block_height = fork_chain.index(b) + 2  # +2因为是父区块的下一个高度
                        break
                if block_height > 0:
                    break

        return block_height % self.blockchain.difficulty_adjustment_interval == 0

    def calculate_new_difficulty(self, adjustment_block: Block, block: Block, chain: list[Block]) -> str:
        """计算新难度值"""
        # 计算这条链上的出块时间差
        time_diff = (block.timestamp - adjustment_block.timestamp).total_seconds()
        blocks_since_adjustment = len(chain) - chain.index(adjustment_block)
        avg_block_time = time_diff / blocks_since_adjustment

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
    new_blocks = miner.start_mining(num_blocks=5)

    # 2. 验证节点同步这些区块
    validator = ValidatorNode()
    # mock shuffle the blocks
    # random.shuffle(new_blocks)
    validator.start_validating(new_blocks)
