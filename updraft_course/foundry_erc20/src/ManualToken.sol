//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract ManualToken {
    mapping(address => uint256) private s_balances;

    function name() public pure returns (string memory) {
        return "Manual Token";
    }

    function totalSupply() public pure returns (uint256) {
        return 100 ether; // 总供应量：100个代币 (100 * 10^18 wei)
    }

    function decimals() public pure returns (uint8) {
        return 18; // 18位小数，1个代币 = 10^18个最小单位
    }

    function balanceOf(address _owner) public view returns (uint256) {
        return s_balances[_owner];
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        require(s_balances[msg.sender] >= _value, "Insufficient balance");
        s_balances[msg.sender] -= _value;
        s_balances[_to] += _value;
        return true;
    }
}
