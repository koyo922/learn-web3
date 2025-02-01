// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {OurToken} from "../src/OurToken.sol";
import {DeployOurToken} from "../script/DeployOurToken.s.sol";

contract OurTokenTest is Test {
    OurToken public ourToken;
    DeployOurToken public deployer;
    uint256 public constant STARTING_BALANCE = 100 ether;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        console.log("Before deployment:");
        console.log("- test contract (this):", address(this));
        console.log("- msg.sender:", msg.sender);

        deployer = new DeployOurToken();
        ourToken = deployer.run();

        console.log("\nAfter deployment:");
        console.log("- deployer contract:", address(deployer));
        console.log("- test contract (this):", address(this));
        console.log("- msg.sender:", msg.sender);
        console.log("\nToken balances:");
        console.log("- msg.sender balance:", ourToken.balanceOf(msg.sender));
        console.log("- this balance:", ourToken.balanceOf(address(this)));
        console.log("- deployer balance:", ourToken.balanceOf(address(deployer)));

        vm.prank(msg.sender);
        ourToken.transfer(bob, STARTING_BALANCE);
    }

    function testBobBalance() public view {
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE);
    }

    function testAllowance() public {
        uint256 initialAllowance = 1000;
        vm.prank(bob);
        ourToken.approve(alice, initialAllowance);

        vm.prank(alice);
        ourToken.transferFrom(bob, alice, initialAllowance);

        assertEq(ourToken.balanceOf(alice), initialAllowance);
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE - initialAllowance);
    }
}
