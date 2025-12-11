// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.5.0
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";

contract RaffleScript is Script {
    Raffle raffleContract;
    uint256 subscriptionId = 1;
    address owner = address(0xABCD);
    address aliceToken = address(0x1234);

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        raffleContract = new Raffle(subscriptionId, address(aliceToken));

        vm.stopBroadcast();
    }
}
