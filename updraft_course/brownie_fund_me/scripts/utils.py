from brownie import accounts, network, config, MockV3Aggregator
from web3 import Web3

STARTING_PRICE = 2000
LOCAL_BLOCKCHAIN_ENVIRONMENTS = ["development", "ganache-gui", "ganache-cli"]


def get_account():
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        return accounts[0]  # ganache
    else:
        return accounts.add(config["wallets"]["from_key"])  # sepolia


def deploy_mocks():
    """Deploy mock price feed if we are on local network"""
    print(f"The active network is {network.show_active()}")
    print("Deploying Mocks...")
    if len(MockV3Aggregator) <= 0:
        MockV3Aggregator.deploy(9*2, Web3.to_wei(STARTING_PRICE, "ether"), {"from": get_account()})
    print("Mocks Deployed!")
    return MockV3Aggregator[-1].address
