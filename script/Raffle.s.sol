// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";

contract RaffleScript is Script {
    Raffle public Raffle;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        Raffle = new Raffle();

        vm.stopBroadcast();
    }
}
