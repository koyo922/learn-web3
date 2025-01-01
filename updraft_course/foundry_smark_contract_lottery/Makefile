# ref: https://github.com/Cyfrin/foundry-fund-me-cu/blob/main/Makefile
include ../../.env

.PHONY: all test clean deploy fund help install snapshot format anvil 

DEFAULT_ANVIL_KEY := $(PRIVATE_KEY_ANVIL)

help:
	@echo "使用说明:"
	@echo "  make deploy-raffle      - 部署 Raffle 合约"
	@echo "  make create-sub         - 创建 VRF 订阅"
	@echo "  make fund-sub           - 资助 VRF 订阅"
	@echo "  make add-consumer       - 添加消费者到 VRF 订阅"

# 部署相关命令
NETWORK_ARGS := --rpc-url $(CHAIN_URL_ANVIL) --private-key $(DEFAULT_ANVIL_KEY) --broadcast

ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(RPC_URL_ETH) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

deploy-raffle:
	@forge script script/DeployRaffle.s.sol:DeployRaffle $(NETWORK_ARGS)

create-sub:
	@forge script script/Interactions.s.sol:CreateSubscription $(NETWORK_ARGS)

fund-sub:
	@forge script script/Interactions.s.sol:FundSubscription $(NETWORK_ARGS)

add-consumer:
	@forge script script/Interactions.s.sol:AddConsumer $(NETWORK_ARGS) 