#!/usr/bin/env python3
# ref https://www.geeksforgeeks.org/implementing-the-proof-of-work-algorithm-in-python-for-blockchain-mining/

import hashlib
import datetime
from typing import Any


class Block:
    def __init__(self, data, previous_hash=''):
        self.data = data  # the transaction records during a 10min interval
        self.previous_hash = previous_hash  # optional, as will be overwritten in Blockchain.add_block()
        self.timestamp = datetime.datetime.now()
        self.nonce = 0
        self.hash = self.calculate_hash()

    def calculate_hash(self):
        sha = hashlib.sha256()
        sha.update(
            str(self.data).encode()
            + str(self.previous_hash).encode()
            # + str(self.timestamp).encode()
            + str(self.nonce).encode()
        )
        return sha.hexdigest()

    def mine_block(self, target_prefix: str):
        while self.hash[:len(target_prefix)] != target_prefix:
            self.nonce += 1
            self.hash = self.calculate_hash()
        print(f"Block mined: {self.hash}")


class Blockchain:
    def __init__(self):
        self.chain = [self.create_genesis_block()]

    def create_genesis_block(self):
        return Block("Genesis Block", "0")

    def add_block(self, new_block: Block):
        new_block.previous_hash = self.chain[-1].hash
        new_block.mine_block("000000")
        self.chain.append(new_block)


if __name__ == "__main__":
    blockchain = Blockchain()
    blockchain.add_block(Block(data="Block 1"))
    blockchain.add_block(Block(data="Block 2"))
    blockchain.add_block(Block(data="Block 3"))
