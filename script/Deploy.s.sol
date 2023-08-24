// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;
import "forge-std/Script.sol";

import {Splitter} from "src/Splitter.sol";
import {SplitterFactory} from "src/SplitterFactory.sol";

contract DeployScript is Script {
    function run() public {
        vm.broadcast();
        new SplitterFactory();
    }
}
