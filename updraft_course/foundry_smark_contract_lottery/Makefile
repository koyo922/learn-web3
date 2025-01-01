-include ../../.env

.PHONY: all test deploy fund

help:
	@echo "Usage:"
	@echo "  make deploy-anvil                    部署到Anvil本地网络"
	@echo "  make deploy-sepolia                  部署到Sepolia测试网"
	@echo "  make create-subscription-anvil        在Anvil上创建VRF订阅"
	@echo "  make create-subscription-sepolia      在Sepolia上创建VRF订阅"
	@echo "  make fund-subscription-anvil          在Anvil上为VRF订阅充值"
	@echo "  make fund-subscription-sepolia        在Sepolia上为VRF订阅充值"

# 部署命令
deploy-anvil:
	@forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $(CHAIN_URL_ANVIL) \
		--private-key $(PRIVATE_KEY_ANVIL) --broadcast -vvv

deploy-sepolia:
	@forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $(RPC_URL_ETH) \
		--private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvv

# VRF订阅相关命令
create-subscription-anvil:
	@forge script script/Interactions.s.sol:CreateSubscription --rpc-url $(CHAIN_URL_ANVIL) \
		--private-key $(PRIVATE_KEY_ANVIL) --broadcast -vvv

create-subscription-sepolia:
	@forge script script/Interactions.s.sol:CreateSubscription --rpc-url $(RPC_URL_ETH) \
		--private-key $(PRIVATE_KEY) --broadcast -vvv

fund-subscription-anvil:
	@forge script script/Interactions.s.sol:FundSubscription --rpc-url $(CHAIN_URL_ANVIL) \
		--private-key $(PRIVATE_KEY_ANVIL) --broadcast -vvv

fund-subscription-sepolia:
	@forge script script/Interactions.s.sol:FundSubscription --rpc-url $(RPC_URL_ETH) \
		--private-key $(PRIVATE_KEY) --broadcast -vvv 