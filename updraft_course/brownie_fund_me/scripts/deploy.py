from brownie import FundMe, config, network
from scripts.utils import get_account, deploy_mocks, LOCAL_BLOCKCHAIN_ENVIRONMENTS
import ipdb


def deploy_fund_me():
    account = get_account()
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        price_feed_address = config["networks"][network.show_active()]["eth_usd_price_feed"]
    else:
        price_feed_address = deploy_mocks()

    fund_me = FundMe.deploy(
        price_feed_address,
        {"from": account},
        publish_source=(
            False if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS
            else config["networks"][network.show_active()]["verify"]
        )
    )
    print(f"Contract deployed to {fund_me.address}")


def main():
    try:
        deploy_fund_me()
    except Exception as e:
        print(f"Error occurred: {e}")
        ipdb.post_mortem()
