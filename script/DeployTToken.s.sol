// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {TToken} from "../src/TerryToken.sol";

contract TTokenScript is Script {
    function run(string memory name, string memory symbol) public {
        vm.startBroadcast();

        TToken ttoken = new TToken(name, symbol);
        console.log("token address:", address(ttoken));

        vm.stopBroadcast();
    }
}
