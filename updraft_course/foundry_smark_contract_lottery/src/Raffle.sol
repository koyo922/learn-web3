// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

error Raffle_NotEnoughEthSent();

/**
 * @title A sample Raffle Contract
 * @author Patrick Collins (or even better, you own name)
 * @notice This contract is for creating a sample raffle
 * @dev It implements Chainlink VRFv2.5 and Chainlink Automation
 */
contract Raffle {
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;

    event EnteredRaffle(address indexed player); // 带索引的参数(topics)更易于检索

    constructor(uint256 entranceFee) {
        i_entranceFee = entranceFee;
    }

    // external 比 public 更便宜
    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, "Not enough ETH sent");
        if (msg.value < i_entranceFee) revert Raffle_NotEnoughEthSent(); // 自定义Error类型，比require更便宜
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    function pickWinner() public {}

    /** Getter Function */

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
