// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.5.0
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";

//Sepolia subscription id:
contract RaffleScript is Script {
    Raffle raffleContract;
    uint256 subscriptionId = 29798300099173099017092510159386407287862520034448296410164372830033307388568;
    address owner = address(0x5991AA8b650D8d58a57663C18BEc57b8DD25CED9);
    address aliceToken = address(0xAC51066d7bEC65Dc4589368da368b212745d63E8);
    address vrfCoordinator = address(0xD7f86b4b8Cae7D942340FF628F82735b7a20893a);
    bytes32 keyHash = 0xc6bf2e7b88e5cfbb4946ff23af846494ae1f3c65270b79ee7876c9aa99d3d45f;
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