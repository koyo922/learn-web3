# ref: https://github.com/Cyfrin/foundry-fund-me-cu/blob/main/Makefile
include ../../.env

.PHONY: all test clean deploy fund help install snapshot format anvil 

DEFAULT_ANVIL_KEY := $(ANVIL_PRIVATE_KEY)

help:
	@echo "使用说明:"
	@echo "  make deploy-raffle      - 部署 Raffle 合约"
	@echo "  make create-sub         - 创建 VRF 订阅"
	@echo "  make fund-sub           - 资助 VRF 订阅"
	@echo "  make add-consumer       - 添加消费者到 VRF 订阅"
	@echo "测试命令:"
	@echo "  make test              - 运行所有测试"
	@echo "  make test-watch        - 监视模式运行测试"
	@echo "  make test-debug        - 调试模式运行测试"
	@echo "  make test-sepolia      - 在 Sepolia fork 上运行测试"
	@echo "  make test-calculating-sepolia - 在 Sepolia fork 上运行 testPlayerCanNotEnterWhileRaffleIsCalculating"
	@echo "  make coverage          - 生成测试覆盖率报告"
	@echo "  make snapshot          - 创建测试快照"

# 部署相关命令
# 注意：验证相关的配置已移至 foundry.toml
# 这里只保留必要的网络参数
NETWORK_ARGS := --rpc-url $(ANVIL_RPC_URL) --private-key $(DEFAULT_ANVIL_KEY) --broadcast

ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(ETH_SEPOLIA_RPC_URL) --private-key $(ETH_PRIVATE_KEY) --broadcast -vvvv
endif

deploy-raffle:
	@forge script script/DeployRaffle.s.sol:DeployRaffle $(NETWORK_ARGS)

create-sub:
	@forge script script/Interactions.s.sol:CreateSubscription $(NETWORK_ARGS)

fund-sub:
	@forge script script/Interactions.s.sol:FundSubscription $(NETWORK_ARGS)

add-consumer:
	@forge script script/Interactions.s.sol:AddConsumer $(NETWORK_ARGS) 

# 测试相关命令
test:
	@forge test

test-watch:
	@forge test --watch

test-debug:
	@forge test -vvvv

test-sepolia:
	@forge test --fork-url $(ETH_SEPOLIA_RPC_URL) -vvvv

test-calculating-sepolia:
	@forge test --match-test testPlayerCanNotEnterWhileRaffleIsCalculating --fork-url $(ETH_SEPOLIA_RPC_URL) -vvvv

coverage:
	@forge coverage --report debug > coverage.txt

snapshot:
	@forge snapshot 