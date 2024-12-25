"""
brownie accounts new account1  # type in the private key in .env
brownie scripts/deploy.py  # 会自动拉起 ganache, 或者attach到已经启动的ganache
"""

import os
from brownie import accounts, config, SimpleStorage


def deploy_simple_storage():
    # account = accounts[0]  # ganache
    # account = accounts.load("account1")  # manually loaded
    # account = accounts.add(os.getenv("PRIVATE_KEY"))  # loaded from .env
    account = accounts.add(config["wallets"]["from_key"])  # loaded from .yaml using .env
    print(account)

    simple_storage = SimpleStorage.deploy({"from": account})
    tx = simple_storage.store(15, {"from": account})
    tx.wait(1)
    return simple_storage


def main():
    deploy_simple_storage()
