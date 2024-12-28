# learn-web3

## 开发指南

### 依赖管理
本项目使用 git submodules 管理依赖。克隆项目后，请执行：

```bash
# 方法1：克隆时直接获取所有子模块
git clone --recursive https://github.com/YOUR_USERNAME/learn-web3.git

# 方法2：克隆后再获取子模块
git clone https://github.com/YOUR_USERNAME/learn-web3.git
cd learn-web3
git submodule update --init --recursive
```

### 添加新依赖的最佳实践
当你需要添加新的依赖时：

```bash
# 直接使用 forge install，它会：
# 1. 拉取依赖到 lib/ 目录
# 2. 自动暂存 .gitmodules 文件
# 3. 创建一个提交
forge install <dependency_name>

# 如果需要特定版本：
forge install <org>/<repo>@<version>  # 例如：forge install transmissions11/solmate@v7

# 更新依赖
forge update lib/<name>  # 更新单个依赖
forge update            # 更新所有依赖

# 移除依赖
forge remove <name>     # 两种方式都可以
forge remove lib/<name>
```

注意事项：
- forge install 会自动处理 git submodule，无需手动添加
- 默认安装 master 分支的最新版本
- 建议指定版本号以确保依赖版本的一致性

### 子模块说明
- `forge-std`: Foundry 的标准库，提供测试工具
- `chainlink-brownie-contracts`: Chainlink 的智能合约接口