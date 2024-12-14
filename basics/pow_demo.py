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

    def __init__(self, data, previous_hash):
        # 由矿工节点执行：
        # - 收集一段时间内(约10分钟)的交易
        # - 将交易打包成区块
        self.data = data  # the transaction records during a 10min interval
        self.previous_hash = previous_hash
        self.timestamp = datetime.datetime.now()
        self.nonce = 0
        self.difficulty = "0000"  # 每个区块都存储当时的难度值
        self.block_reward = 50  # 比特币最初的区块奖励是50 BTC
        self.miner_address = None  # 记录获得奖励的矿工地址
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
genesis_block.miner_address = "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"  # 设置创世区块矿工地址


class Blockchain:
    """区块链结构
    在分布式系统中：
    - 每个节点都维护完整的区块链副本
    - 通过共识机制确保网络中的区块链一致性
    """

    def __init__(self):
        self.chain = [genesis_block]  # 所有节点从相同的创世区块开始
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
        for i, b in enumerate(self.blockchain.chain):
            if b.hash == block.previous_hash:
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

        for orphan_hash, orphan_block in list(self.orphan_blocks.items()):
            if orphan_block.previous_hash == parent_hash:
                if self.verify_block(orphan_block):
                    self.blockchain.chain.append(orphan_block)
                    print(f"Previous-Orphan Block added to some chain: {orphan_block.hash[:10]}...")
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
        3. 验证哈希计算结果是否正确
        4. 验证交易是否有双重支付
        """
        # 验证难度值
        expected_difficulty = self.calculate_expected_difficulty(block)
        if block.difficulty != expected_difficulty:
            print(f"Invalid difficulty: expected {expected_difficulty}, got {block.difficulty}")
            return False
        # 验证哈希是否满足难度要求
        if not block.hash.startswith(block.difficulty):
            return False
        # 验证哈希计算结果
        calculated_hash = block.calculate_hash()
        if calculated_hash != block.hash:
            print(f"Invalid hash: calculated {calculated_hash}, got {block.hash}")
            return False

        # 找到此区块将要插入的位置
        parent_position = -1
        current_position = len(self.blockchain.chain)  # 当前区块将在链上的位置
        for i, b in enumerate(self.blockchain.chain):
            if b.hash == block.previous_hash:
                parent_position = i
                current_position = i + 1
                break

        if parent_position == -1:
            print(f"Debug: Block {block.hash[:8]} is orphan, parent not found")
            return True

        print(f"\nDebug: Verifying block at position {current_position}")
        print(f"Debug: Parent block is at position {parent_position}")

        # 计算可用余额
        spent_outputs = {}
        # 创世区块奖励直接可用
        genesis = self.blockchain.chain[0]
        spent_outputs[genesis.miner_address] = genesis.block_reward
        print(f"Debug: Initial balance from genesis: {genesis.miner_address[:8]} = {genesis.block_reward}")

        # 遍历到父区块位置的所有交易
        for i in range(1, current_position):
            b = self.blockchain.chain[i]
            print(f"\nDebug: Checking block {i} (confirmations: {current_position - i})")

            # 只统计已确认的区块
            if current_position - i >= 2:
                print(f"Debug: Block {i} is confirmed")
                # 先加入区块奖励
                spent_outputs[b.miner_address] = spent_outputs.get(b.miner_address, 0) + b.block_reward
                print(f"Debug: Added block reward: {b.miner_address[:8]} += {b.block_reward}")
                
                # 处理交易
                for tx in b.data:
                    if isinstance(tx, Transaction):
                        print(f"Debug: Processing tx: {tx.sender[:8]} -> {tx.receiver[:8]} = {tx.amount} (fee: {tx.fee})")
                        if tx.sender in spent_outputs:
                            spent_outputs[tx.sender] -= (tx.amount + tx.fee)
                        if tx.receiver in spent_outputs:
                            spent_outputs[tx.receiver] = spent_outputs.get(tx.receiver, 0) + tx.amount
                        else:
                            spent_outputs[tx.receiver] = tx.amount
                        spent_outputs[b.miner_address] += tx.fee  # 只加手续费
                print(f"Debug: After block {i}, balances: {[(k[:8], v) for k, v in spent_outputs.items()]}")
            else:
                print(f"Debug: Block {i} not confirmed yet")

        print("\nDebug: Verifying transactions in current block:")
        # 验证当前区块的交易，同时更新临时余额状态
        temp_outputs = spent_outputs.copy()  # 创建临时余额状态
        for tx in block.data:
            if isinstance(tx, Transaction):
                sender_balance = temp_outputs.get(tx.sender, 0)  # 使用临时状态
                print(f"Debug: Checking tx: {tx.sender[:8]} -> {tx.receiver[:8]} = {tx.amount} (fee: {tx.fee})")
                print(f"Debug: Sender {tx.sender[:8]} balance: {sender_balance}")
                if sender_balance < (tx.amount + tx.fee):
                    print(f"Double spend detected: {tx.sender} tried to spend more than their balance")
                    print(f"Balance: {sender_balance}, Trying to spend: {tx.amount + tx.fee}")
                    return False
                    
                # 更新临时余额状态
                temp_outputs[tx.sender] = sender_balance - (tx.amount + tx.fee)
                temp_outputs[tx.receiver] = temp_outputs.get(tx.receiver, 0) + tx.amount
                temp_outputs[block.miner_address] = temp_outputs.get(block.miner_address, 0) + tx.fee
                print(f"Debug: After tx, temp balances: {[(k[:8], v) for k, v in temp_outputs.items()]}")

        return True

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
                print(f"Debug: block_height={block_height}, interval={self.blockchain.difficulty_adjustment_interval}")
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

        # 添加调试信息
        print(f"Debug: avg_block_time={avg_block_time}, target={self.blockchain.target_block_time}")
        print(f"Debug: current difficulty={adjustment_block.difficulty}")

        # 问题在这里：难度调整逻辑可能有问题
        if avg_block_time < self.blockchain.target_block_time:
            return "0" + adjustment_block.difficulty
        elif avg_block_time > self.blockchain.target_block_time:
            return adjustment_block.difficulty[1:]
        return adjustment_block.difficulty

    def get_balance(self, address: str) -> float:
        """计算地址的当前余额
        注意：
        1. 创世区块奖励可以直接使用
        2. 其他区块奖励需要等待确认
        """
        balance = 0
        current_height = len(self.blockchain.chain)

        # 遍历主链上所有区块
        for i, block in enumerate(self.blockchain.chain):
            # 如果是创世区块，奖励直接可用
            if i == 0 and block.miner_address == address:
                balance += block.block_reward
                continue

            # 处理区块中的交易
            for tx in block.data:
                if isinstance(tx, Transaction):
                    # 如果是发送方，减去金额和手续费
                    if tx.sender == address:
                        balance -= (tx.amount + tx.fee)
                    # 如果是接收方，加上金额
                    if tx.receiver == address:
                        balance += tx.amount
                    # 如果是矿工，加上手续费
                    if block.miner_address == address:
                        balance += tx.fee

            # 区块奖励：创世区块之后的奖励需要等待确认
            if block.miner_address == address and i > 0:
                # 在演示中我们设置较小的确认数(比如2)，而不是比特币的100
                if current_height - i >= 2:
                    balance += block.block_reward

        return balance


class Transaction:
    def __init__(self, sender: str, receiver: str, amount: float, fee: float):
        self.sender = sender
        self.receiver = receiver
        self.amount = amount
        self.fee = fee


class TransactionPool:
    """模拟内存池，存储待确认的交易"""

    def __init__(self):
        self.pending_transactions = []

    def add_transaction(self, tx: Transaction):
        self.pending_transactions.append(tx)

    def get_transactions(self, chain: list[Block], max_count: int = 3) -> list[Transaction]:
        """获取可以打包的交易，需要考虑确认数"""
        valid_txs = []
        current_height = len(chain)

        # 计算当前可用余额（考虑确认数）
        balances = {}
        # 创世区块奖励直接可用
        genesis = chain[0]
        balances[genesis.miner_address] = genesis.block_reward

        # 遍历其他区块
        for i, block in enumerate(chain[1:], 1):
            # 只统计已确认的区块（至少2个确认）
            if current_height - i >= 2:
                if block.miner_address in balances:
                    balances[block.miner_address] += block.block_reward
                else:
                    balances[block.miner_address] = block.block_reward

                for tx in block.data:
                    if isinstance(tx, Transaction):
                        # 更新发送方余额
                        if tx.sender in balances:
                            balances[tx.sender] -= (tx.amount + tx.fee)
                        # 更新接收方余额
                        if tx.receiver in balances:
                            balances[tx.receiver] += tx.amount
                        else:
                            balances[tx.receiver] = tx.amount
                        # 更新矿工手续费
                        balances[block.miner_address] += tx.fee

        # 根据可用余额筛选交易
        for tx in sorted(self.pending_transactions, key=lambda t: t.fee, reverse=True):
            sender_balance = balances.get(tx.sender, 0)
            if sender_balance >= (tx.amount + tx.fee):
                valid_txs.append(tx)
                # 更新余额状态
                balances[tx.sender] -= (tx.amount + tx.fee)
                balances[tx.receiver] = balances.get(tx.receiver, 0) + tx.amount
                if len(valid_txs) >= max_count:
                    break

        return valid_txs

    def remove_transactions(self, txs: list[Transaction]):
        """从交易池中移除已打包的交易"""
        for tx in txs:
            if tx in self.pending_transactions:
                self.pending_transactions.remove(tx)


class MinerNode(Node):
    def __init__(self, address: str):
        super().__init__()
        self.address = address
        self.balance = 0
        self.mempool = TransactionPool()

    def start_mining(self, num_blocks: int = 3) -> list[Block]:
        mined_blocks = []
        blocks_mined = 0

        while blocks_mined < num_blocks:
            # 从交易池获取待打包交易，传入当前链状态
            transactions = self.mempool.get_transactions(self.blockchain.chain)

            new_block = Block(transactions, self.blockchain.chain[-1].hash)
            new_block.miner_address = self.address

            tx_fees = sum(tx.fee for tx in transactions)
            total_reward = new_block.block_reward + tx_fees

            current_difficulty = self.calculate_expected_difficulty(new_block)
            new_block.mine_block(current_difficulty)

            self.balance = self.get_balance(self.address)
            if transactions:
                print(f"Miner {self.address[:8]} earned {total_reward} coins! (Block reward: {new_block.block_reward}, Fees: {tx_fees})")
            else:
                print(f"Miner {self.address[:8]} earned {total_reward} coins! (Empty block, only reward)")

            # 从交易池移除已打包的交易
            self.mempool.remove_transactions(transactions)

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

    # 1. 创建一些测试交易，但数量少于要挖的区块数
    mempool = TransactionPool()
    test_transactions = [
        # 只创建3笔交易，但要挖5个区块
        Transaction(genesis_block.miner_address, "Alice", 10.0, 0.1),  # 使用创世区块矿工地址
        Transaction("Alice", "Bob", 5.0, 0.15),
        Transaction("Bob", "Charlie", 2.0, 0.05),
    ]
    for tx in test_transactions:
        mempool.add_transaction(tx)

    # 2. 矿工开始挖矿
    miner = MinerNode("1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa")
    miner.mempool = mempool  # 设置交易池
    new_blocks = miner.start_mining(num_blocks=5)
    print(f"Miner's final balance: {miner.balance} coins")

    # 3. 验证节点验证这些区块
    validator = ValidatorNode()
    random.shuffle(new_blocks)  # 模拟网络传输顺序随机
    validator.start_validating(new_blocks)

"""
=== Simulating Blockchain Network with Difficulty Sync ===
Debug: block_height=2, interval=4
Block mined with difficulty 4: 00006526ffc40641c711aa879dba670018141d9821a382dd73bce2888fec9e13
Miner 1A1zP1eP earned 50.1 coins! (Block reward: 50, Fees: 0.1)
Debug: block_height=3, interval=4
Block mined with difficulty 4: 0000920db510b57262c67849e82461c75f1682627a8bef2da6d8812997f64320
Miner 1A1zP1eP earned 50 coins! (Empty block, only reward)
Debug: block_height=4, interval=4
Debug: avg_block_time=0.148396, target=1
Debug: current difficulty=0000
Block mined with difficulty 5: 00000d9d764ce0f4c981fd1478d6926cabfc1fe8f51480819398e60d6f8bf013
Miner 1A1zP1eP earned 50.2 coins! (Block reward: 50, Fees: 0.2)
Debug: block_height=5, interval=4
Block mined with difficulty 5: 00000a4f6a7ef88e8da45ab1912d7139b0d573274fbf487f8bb7b4794cf8899d
Miner 1A1zP1eP earned 50 coins! (Empty block, only reward)
Debug: block_height=6, interval=4
Block mined with difficulty 5: 00000cf2e877832e7bda7d3cf945e041005da13a2c4f1792ceb62449d258d5e7
Miner 1A1zP1eP earned 50 coins! (Empty block, only reward)
Miner's final balance: 190.20000000000002 coins

Validator: Starting validation process

Node: Starting blockchain sync...
Debug: block_height=2, interval=4

Debug: Verifying block at position 1
Debug: Parent block is at position 0
Debug: Initial balance from genesis: 1A1zP1eP = 50

Debug: Verifying transactions in current block:
Debug: Checking tx: 1A1zP1eP -> Alice = 10.0 (fee: 0.1)
Debug: Sender 1A1zP1eP balance: 50
Debug: After tx, temp balances: [('1A1zP1eP', 40.0), ('Alice', 10.0)]
Block added to main chain: 00006526ff...
Debug: Block 00000a4f is orphan, parent not found
Orphan block stored: 00000a4f6a...
Debug: Block 00000cf2 is orphan, parent not found
Orphan block stored: 00000cf2e8...
Debug: block_height=3, interval=4

Debug: Verifying block at position 2
Debug: Parent block is at position 1
Debug: Initial balance from genesis: 1A1zP1eP = 50

Debug: Checking block 1 (confirmations: 1)
Debug: Block 1 not confirmed yet

Debug: Verifying transactions in current block:
Block added to main chain: 0000920db5...
Debug: block_height=4, interval=4
Debug: avg_block_time=0.148396, target=1
Debug: current difficulty=0000

Debug: Verifying block at position 3
Debug: Parent block is at position 2
Debug: Initial balance from genesis: 1A1zP1eP = 50

Debug: Checking block 1 (confirmations: 2)
Debug: Block 1 is confirmed
Debug: Added block reward: 1A1zP1eP += 50
Debug: Processing tx: 1A1zP1eP -> Alice = 10.0 (fee: 0.1)
Debug: After block 1, balances: [('1A1zP1eP', 90.0), ('Alice', 10.0)]

Debug: Checking block 2 (confirmations: 1)
Debug: Block 2 not confirmed yet

Debug: Verifying transactions in current block:
Debug: Checking tx: Alice -> Bob = 5.0 (fee: 0.15)
Debug: Sender Alice balance: 10.0
Debug: After tx, temp balances: [('1A1zP1eP', 90.15), ('Alice', 4.85), ('Bob', 5.0)]
Debug: Checking tx: Bob -> Charlie = 2.0 (fee: 0.05)
Debug: Sender Bob balance: 5.0
Debug: After tx, temp balances: [('1A1zP1eP', 90.2), ('Alice', 4.85), ('Bob', 2.95), ('Charlie', 2.0)]
Block added to main chain: 00000d9d76...
Debug: block_height=5, interval=4

Debug: Verifying block at position 4
Debug: Parent block is at position 3
Debug: Initial balance from genesis: 1A1zP1eP = 50

Debug: Checking block 1 (confirmations: 3)
Debug: Block 1 is confirmed
Debug: Added block reward: 1A1zP1eP += 50
Debug: Processing tx: 1A1zP1eP -> Alice = 10.0 (fee: 0.1)
Debug: After block 1, balances: [('1A1zP1eP', 90.0), ('Alice', 10.0)]

Debug: Checking block 2 (confirmations: 2)
Debug: Block 2 is confirmed
Debug: Added block reward: 1A1zP1eP += 50
Debug: After block 2, balances: [('1A1zP1eP', 140.0), ('Alice', 10.0)]

Debug: Checking block 3 (confirmations: 1)
Debug: Block 3 not confirmed yet

Debug: Verifying transactions in current block:
Previous-Orphan Block added to some chain: 00000a4f6a...
Debug: block_height=6, interval=4

Debug: Verifying block at position 5
Debug: Parent block is at position 4
Debug: Initial balance from genesis: 1A1zP1eP = 50

Debug: Checking block 1 (confirmations: 4)
Debug: Block 1 is confirmed
Debug: Added block reward: 1A1zP1eP += 50
Debug: Processing tx: 1A1zP1eP -> Alice = 10.0 (fee: 0.1)
Debug: After block 1, balances: [('1A1zP1eP', 90.0), ('Alice', 10.0)]

Debug: Checking block 2 (confirmations: 3)
Debug: Block 2 is confirmed
Debug: Added block reward: 1A1zP1eP += 50
Debug: After block 2, balances: [('1A1zP1eP', 140.0), ('Alice', 10.0)]

Debug: Checking block 3 (confirmations: 2)
Debug: Block 3 is confirmed
Debug: Added block reward: 1A1zP1eP += 50
Debug: Processing tx: Alice -> Bob = 5.0 (fee: 0.15)
Debug: Processing tx: Bob -> Charlie = 2.0 (fee: 0.05)
Debug: After block 3, balances: [('1A1zP1eP', 190.20000000000002), ('Alice', 4.85), ('Bob', 2.95), ('Charlie', 2.0)]

Debug: Checking block 4 (confirmations: 1)
Debug: Block 4 not confirmed yet

Debug: Verifying transactions in current block:
Previous-Orphan Block added to some chain: 00000cf2e8...
Sync finished. Chain length: 6, Remaining orphans: 0
Validator: Finished processing 5 blocks
"""
