## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

# Address Relationships in Test

```mermaid
graph TB
    subgraph Foundry["Foundry Test Environment"]
        MSG["msg.sender<br>0x1804c8AB...1f38<br>Default Test Account"]
        TEST["Test Contract this<br>0x7FA9385...1496<br>OurTokenTest"]
        DEPLOY["Deployer Contract<br>0x5615dEB...72f<br>DeployOurToken"]
        TOKEN["Token Contract<br>OurToken"]
        BOB["bob<br>test account"]
    end

    TEST -->|creates| DEPLOY
    TEST -->|calls| DEPLOY
    DEPLOY -->|deploys| TOKEN
    MSG -->|becomes owner| TOKEN
    MSG -->|transfers| BOB

    style MSG fill:#f9f,stroke:#333
    style TOKEN fill:#bbf,stroke:#333
    style TEST fill:#bfb,stroke:#333
    style DEPLOY fill:#fbb,stroke:#333
    style BOB fill:#ddd,stroke:#333

    note1[Test contract executes but not owns tokens]
    note2[msg.sender is Foundry default test account]
    note3[vm.broadcast sets msg.sender as token owner]

    classDef note fill:#fff,stroke:#333,stroke-dasharray: 5 5
    class note1,note2,note3 note
```

关键点说明：
1. `this` (测试合约) 虽然是执行者，但不是代币所有者
2. `msg.sender` 是 Foundry 设置的默认测试账户
3. **`vm.broadcast()` 使得代币所有者变成了 `msg.sender` 而不是测试合约**
4. 部署合约（DeployOurToken）只是一个工具合约，不持有任何代币