// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @dev 在Solidity中，事件(Event)不像Python中的类或对象那样可以直接导入和重用
 * 这是因为事件实际上是EVM(以太坊虚拟机)日志系统的抽象，它们会被记录在区块链上
 *
 * 为了避免在多个文件中重复定义相同的事件(比如在合约和测试中)，
 * 我们使用接口(Interface)来集中定义这些事件。
 * 这类似于Python中的抽象基类(ABC)或接口类的概念，但实现方式不同。
 *
 * 任何需要使用这些事件的合约都可以继承这个接口，
 * 从而实现事件定义的重用，使代码更DRY（Don't Repeat Yourself）。
 */
interface IRaffle {
    event EnteredRaffle(address indexed player);
    event WinnerPicked(address indexed winner);
}
