from brownie import accounts, SimpleStorage, network, config
from brownie.test import given, strategy
import pytest


def get_account():
    if network.show_active() == "development":
        return accounts[0]  # ganache
    else:
        return accounts.add(config["wallets"]["from_key"])  # sepolia


def test_deploy():
    account = get_account()
    simple_storage = SimpleStorage.deploy({"from": account})
    assert simple_storage.retrieve() == 0


def test_updating_storage():
    account = get_account()
    simple_storage = SimpleStorage.deploy({"from": account})
    expected = 15
    simple_storage.store(expected, {"from": account})
    assert simple_storage.retrieve() == expected


"""
Fuzzing test for store/retrieve functionality:
1. 每次运行会测试多个随机值（默认是50个不同的值）
2. 只能在development网络上运行，因为需要evm_snapshot功能来快速重置状态
3. 目的是测试合约在各种不同输入值下的行为是否符合预期
4. 可以发现边界情况和异常情况（比如超大数字、0等特殊值）
"""


@pytest.mark.skipif(
    network.show_active() != "development",
    reason="Fuzzing tests only work on development networks"
)
@given(value=strategy('uint256'))
def test_store_retrieve_fuzzing(value):
    account = get_account()
    simple_storage = SimpleStorage.deploy({"from": account})
    simple_storage.store(value, {"from": account})
    assert simple_storage.retrieve() == value
