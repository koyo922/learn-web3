// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// config to avoid warning, ref https://n4n0b1t3.medium.com/how-to-make-vsc-solidity-lint-recognize-your-chainlink-and-openzeppelin-libraries-73775129261c
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract FundMe {
    mapping(address => uint256) public addressToAmountFunded;
    address[] public funders;
    address public owner;

    /* Gas 优化说明：
    使用状态变量 vs 局部变量的取舍:
    1. 状态变量读取成本: SLOAD = 2100 gas (cold access)
       - pure/view 函数调用不收费，因为它们不上链:
         * view: 只读合约状态（像看监控录像）
         * pure: 完全不碰状态（像纯数学计算）
         * 为什么读取不收费：
           - 读取确实消耗节点计算资源
           - 但由本地节点执行，不需要全网共识
           - 如果被非view函数调用，会产生gas成本
       - 高频/循环调用场景应当使用内存变量缓存
    2. 状态变量存储成本:
       - 每个存储槽(32字节): 20,000 gas
       - 每字节部署成本: 200 gas
    3. 当前选择:
       - 优先可维护性，将 priceFeed 作为状态变量
       - 非核心合约，gas 优化非首要考虑
    */
    AggregatorV3Interface public priceFeed;

    constructor(address _priceFeedAddress) {
        owner = msg.sender;
        priceFeed = AggregatorV3Interface(_priceFeedAddress);
    }

    function fund() public payable {
        uint256 minimumUSD = 50 * 10 ** 18;
        require(
            getConversionRate(msg.value) >= minimumUSD,
            "You need to spend more ETH!"
        );
        addressToAmountFunded[msg.sender] += msg.value;
        funders.push(msg.sender);
    }

    function getVersion() public view returns (uint256) {
        return priceFeed.version();
    }

    function getPrice() public view returns (uint256) {
        (, int256 answer, , , ) = priceFeed.latestRoundData();
        return uint256(answer * 10000000000);
    }

    function getConversionRate(
        uint256 ethAmount
    ) public view returns (uint256) {
        uint256 ethPrice = getPrice();
        uint256 ethAmountInUsd = (ethPrice * ethAmount) / 1000000000000000000;
        return ethAmountInUsd;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "You are not the owner!");
        _;
    }

    function withdraw() public payable onlyOwner {
        payable(msg.sender).transfer(address(this).balance);

        for (
            uint256 funderIndex = 0;
            funderIndex < funders.length;
            funderIndex++
        ) {
            address funder = funders[funderIndex];
            addressToAmountFunded[funder] = 0;
        }
        funders = new address[](0);
    }
}
