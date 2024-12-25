from brownie import FundMe
from scripts.utils import get_account
import ipdb


def deploy_fund_me():
    account = get_account()
    fund_me = FundMe.deploy({"from": account}, publish_source=True)
    print(f"Contract deployed to {fund_me.address}")


def main():
    try:
        deploy_fund_me()
    except Exception:
        ipdb.post_mortem()
