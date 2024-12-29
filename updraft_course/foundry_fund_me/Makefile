# ref: https://github.com/Cyfrin/foundry-fund-me-cu/blob/main/Makefile
include ../../.env

.PHONY: all test clean deploy fund help install snapshot format anvil zktest zk-anvil deploy-zk deploy-zk-sepolia

# 默认的 anvil 私钥 - 使用 .env 中的 PRIVATE_KEY_ANVIL
# 这是 anvil 本地测试网络的第一个预设账户私钥
DEFAULT_ANVIL_KEY := $(PRIVATE_KEY_ANVIL)

# zkSync 本地测试网私钥
# 注意：这个值是 zkSync 本地测试网络(zk-anvil)预设的账户私钥
# 1. 不要修改这个值，它是 zkSync 工具链预设的
# 2. 不要使用 .env 中的 PRIVATE_KEY，那是用于实际网络(如 Sepolia)的
# 3. 这里的用法类似于 anvil 的预设账户，专门用于本地开发测试
DEFAULT_ZKSYNC_LOCAL_KEY := 0x7726827caac94a7f9e1b160f7ea819f172f7b6f9d2a97f992c38edeab82d4110

help:
	@echo "使用说明:"
	@echo "  make clean              - 清理编译缓存"
	@echo "  make build              - 编译项目"
	@echo "  make test               - 运行测试"
	@echo "  make snapshot           - 生成 gas 快照"
	@echo "  make anvil              - 启动本地测试网络"
	@echo "  make zk-anvil           - 启动 zkSync 本地测试网络"
	@echo "  make deploy             - 部署到本地网络"
	@echo "  make deploy-sepolia     - 部署到 Sepolia 测试网"
	@echo "  make deploy-zk          - 部署到 zkSync 本地网络"
	@echo "  make deploy-zk-sepolia  - 部署到 zkSync Sepolia 测试网"
	@echo "  make fund               - 向合约注资"
	@echo "  make withdraw           - 从合约提取资金"

# 清理编译缓存
clean:
	forge clean

build:
	forge build

# zkSync 专用编译
zkbuild:
	forge build --zksync

test:
	forge test 

# zkSync 专用测试
zktest:
	foundryup-zksync && forge test --zksync && foundryup

snapshot:
	forge snapshot

format:
	forge fmt

# 启动本地测试网络
anvil:
	anvil --block-time 1

# 启动 zkSync 本地测试网络
zk-anvil:
	pnpx zksync-cli dev start

# 部署相关命令
NETWORK_ARGS := --rpc-url $(CHAIN_URL_ANVIL) --private-key $(DEFAULT_ANVIL_KEY) --broadcast

ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(RPC_URL_ETH) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

deploy:
	@forge script script/DeployFundMe.s.sol:DeployFundMe $(NETWORK_ARGS)

deploy-sepolia:
	@forge script script/DeployFundMe.s.sol:DeployFundMe --rpc-url $(RPC_URL_ETH) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv

# zkSync 部署命令
deploy-zk:
	@forge create src/FundMe.sol:FundMe --rpc-url http://127.0.0.1:8011 --private-key $(DEFAULT_ZKSYNC_LOCAL_KEY) --constructor-args $(shell forge create test/mocks/MockV3Aggregator.sol:MockV3Aggregator --rpc-url http://127.0.0.1:8011 --private-key $(DEFAULT_ZKSYNC_LOCAL_KEY) --constructor-args 8 200000000000 --legacy --zksync | grep "Deployed to:" | awk '{print $$3}') --legacy --zksync

deploy-zk-sepolia:
	@forge create src/FundMe.sol:FundMe --rpc-url $(RPC_URL_ZKSYNC) --account default --constructor-args 0xfEefF7c3fB57d18C5C6Cdd71e45D2D0b4F9377bF --legacy --zksync

# 交互命令
SENDER_ADDRESS := $(MY_ADDRESS)

fund:
	@forge script script/Interactions.s.sol:FundFundMe --sender $(SENDER_ADDRESS) $(NETWORK_ARGS)

withdraw:
	@forge script script/Interactions.s.sol:WithdrawFundMe --sender $(SENDER_ADDRESS) $(NETWORK_ARGS)