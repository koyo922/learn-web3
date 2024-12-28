// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// NOTE: Test contract inherits all assertion functions from forge-std/Test.sol
// No need to import them separately
import {Test} from "forge-std/Test.sol";
import {FundMe} from "../src/FundMe.sol";

contract FundMeTest is Test {
    FundMe fundMe;

    function setUp() external {
        fundMe = new FundMe(address(0));
    }

    // NOTE:
    // 1. MINIMUM_USD is a public variable, but we need to access it as a function: fundMe.MINIMUM_USD()
    // 2. Since this test only reads state, we add the view modifier
    function testMinimumDollarIsFive() public view {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsTestObject() public view {
        assertEq(fundMe.i_owner(), address(this));
    }
}
