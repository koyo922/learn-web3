include ../../.env

# 清理 Forge 缓存，用于解决文件路径变更后的编译问题
clean:
	forge clean

build:
	forge build

deploy-sepolia:
	forge script script/DeployFundMe.s.sol:DeployFundMe --rpc-url ${RPC_URL_ETH} --private-key ${PRIVATE_KEY} --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY} -vvvv