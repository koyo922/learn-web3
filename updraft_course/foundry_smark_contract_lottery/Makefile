# ref: https://github.com/Cyfrin/foundry-fund-me-cu/blob/main/Makefile
include ../../.env

# 环境变量处理说明：
# 1. include ../../.env 只会将变量导入到 Make 的作用域
# 2. 这些变量可以在 Makefile 中使用，如 $(ETH_PRIVATE_KEY)
# 3. 但是，它们默认不会传递给子进程（如 forge script）
#
# 关于 PRIVATE_KEY：
# 1. forge script 的 --private-key 参数会自动设置 PRIVATE_KEY 环境变量
# 2. 所以在 Solidity 中可以直接用 vm.envUint("PRIVATE_KEY")
# 3. 但是 forge test 不支持 --private-key 参数
# 4. 所以测试时需要显式导出 PRIVATE_KEY
export PRIVATE_KEY=$(ETH_PRIVATE_KEY)
#
# 其他环境变量：
# 1. 验证和 RPC 相关的变量仍需要导出(如果用到的话，这里其实没用到)
# 2. 因为它们没有对应的命令行参数自动处理机制
# export ETHERSCAN_API_KEY
# export ETH_SEPOLIA_RPC_URL

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

# 下面这些没有 --fork-url 参数，如果指定了sepolia，则会影响真实的sepolia的网络
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


# 下面这些有 --fork-url 参数，即使指定了sepolia，也不会影响真实的sepolia的网络
test-sepolia:
	@forge test --fork-url $(ETH_SEPOLIA_RPC_URL) -vvvv

test-calculating-sepolia:
	@forge test --match-test testPlayerCanNotEnterWhileRaffleIsCalculating --fork-url $(ETH_SEPOLIA_RPC_URL) -vvvv

coverage:
	@forge coverage --report debug > coverage.txt

snapshot:
	@forge snapshot 