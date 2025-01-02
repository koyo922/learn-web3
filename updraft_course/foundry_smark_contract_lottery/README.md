# Proveably Random Raffle Contracts

## About

This code is to create a proveably random smart contract lottery.

## What we want it to do?

1. Users should be able to enter the raffle by paying for a ticket. The ticket fees are going to be the prize the winner receives.
2. The lottery should automatically and programmatically draw a winner after a certain period.
3. Chainlink VRF should generate a provably random number.
4. Chainlink Automation should trigger the lottery draw regularly.

## Workflow

```mermaid
graph TD
    %% 样式定义
    classDef contractOwner fill:#e6194B,color:white
    classDef player fill:#3cb44b,color:white
    classDef chainlinkNode fill:#4363d8,color:white
    classDef contract fill:#911eb4,color:white
    classDef vrfNode fill:#f58231,color:white

    %% 初始化流程
    subgraph Owner[合约部署者]
        A[部署合约]:::contractOwner --> B[创建订阅]:::contractOwner
        B --> C[充值]:::contractOwner
        C --> D[添加消费者]:::contractOwner
    end

    %% 玩家操作
    subgraph Player[玩家]
        E[玩家]:::player -->|投注| F[合约]:::contract
        F -->|记录| G[玩家列表]
    end

    %% 自动化
    subgraph Auto[自动化节点]
        H[节点]:::chainlinkNode -->|检查| I{检查条件}
        I -->|满足| J[开奖]
        I -->|不满足| H
        
        %% 检查条件
        subgraph Check[条件]
            K[时间到]
            L[开放状态]
            M[有玩家]
            N[有奖金]
            K & L & M & N --> I
        end
    end

    %% VRF
    subgraph VRF[随机数服务]
        J -->|请求| O[VRF节点]:::vrfNode
        O -->|回调| P[接收随机数]
    end

    %% 更新
    subgraph Update[状态更新]
        P --> Q[选择赢家]:::contract
        Q --> R[发奖]
        R --> S[重置]
    end

    %% 状态
    subgraph State[状态机]
        T[开放]:::contract <-->|开奖/完成| U[计算中]:::contract
    end
```

## Contract Addresses

- Sepolia VRF Coordinator: `0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B`
- Sepolia LINK Token: `0x779877A7B0D9E8603169DdbD7836e478b4624789`