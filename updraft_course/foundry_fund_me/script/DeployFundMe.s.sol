// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {FundMe} from "../src/FundMe.sol";
import {Script} from "forge-std/Script.sol";

contract DeployFundMe is Script {
    function run() external {
        vm.startBroadcast();
        new FundMe(address(0));
        vm.stopBroadcast();
    }
}
