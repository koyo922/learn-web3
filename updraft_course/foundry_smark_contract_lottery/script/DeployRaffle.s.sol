// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription} from "./Interactions.s.sol";
import {FundSubscription} from "./Interactions.s.sol";
import {AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        return deployContract();
    }

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();

        console.log("Deploying with config:");
        console.log("subscriptionId:", networkConfig.subscriptionId);
        console.log("vrfCoordinator:", networkConfig.vrfCoordinator);

        if (networkConfig.subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (networkConfig.subscriptionId, networkConfig.vrfCoordinator) = createSubscription.createSubscription(networkConfig.vrfCoordinator);
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(networkConfig.subscriptionId, networkConfig.vrfCoordinator, networkConfig.link);
        }

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            networkConfig.entranceFee,
            networkConfig.interval,
            networkConfig.vrfCoordinator,
            networkConfig.gasLane,
            networkConfig.subscriptionId,
            networkConfig.callbackGasLimit
        );
        vm.stopBroadcast();

        console.log("Raffle deployed at:", address(raffle));
        console.log("Adding consumer to VRF subscription...");
        
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(networkConfig.subscriptionId, networkConfig.vrfCoordinator, address(raffle));
        
        console.log("Consumer added successfully");
        return (raffle, helperConfig);
    }
}
