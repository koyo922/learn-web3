// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployMoodNft} from "../script/DeployMoodNft.s.sol";
import {MoodNft} from "../src/MoodNft.sol";

contract DeployMoodNftTest is Test {
    DeployMoodNft deployer;
    MoodNft moodNft;

    function setUp() public {
        deployer = new DeployMoodNft();
        moodNft = deployer.run();
    }

    function testConvertSvgToImageUri() public view {
        string memory svg = vm.readFile("./img/example.svg");
        string memory actualUri = deployer.svgToImageUri(svg);
        string
            memory expectedUri = "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHhtbG5zOnhsaW5rPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5L3hsaW5rIiB3aWR0aD0iNTAwIiBoZWlnaHQ9IjUwMCI+Cjx0ZXh0IHg9IjAiIHk9IjE1IiBmaWxsPSJibGFjayI+SGkhIFlvdXIgYnJvd3NlciBkZWNvZGVkIHRoaXM8L3RleHQ+Cjwvc3ZnPg==";
        assertEq(actualUri, expectedUri, "URI should be equal");
    }
}
