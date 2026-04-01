// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.5.0
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";


contract RaffleScript is Script {
    Raffle raffleContract;
    uint256 subscriptionId = 96349751094655264643182161929922189477016467088195930821319915882799913221132;
    address owner = address(0x5991AA8b650D8d58a57663C18BEc57b8DD25CED9);
    address aliceToken = address(0xAC51066d7bEC65Dc4589368da368b212745d63E8);
    address vrfCoordinator = address(0xd691f04bc0C9a24Edb78af9E005Cf85768F694C9);
    bytes32 keyHash = 0xb94a4fdb12830e15846df59b27d7c5d92c9c24c10cf6ae49655681ba560848dd;
    uint32 callbackGasLimit = 100_000;
    uint16 requestConfirmations = 3;
    uint32 houseFee = 1000; // 10%

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        raffleContract = new Raffle(
            subscriptionId, aliceToken, vrfCoordinator, keyHash, callbackGasLimit, requestConfirmations, houseFee
        );

        vm.stopBroadcast();
    }
}
