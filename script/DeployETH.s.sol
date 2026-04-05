// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.5.0
pragma solidity ^0.8.19;
import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";

//Sepolia subscription id:
contract RaffleScript is Script {
    Raffle raffleContract;
    uint256 subscriptionId = 53910715258455525673306227434249246930644578090699990663112838043934870643230;
    address owner = address(0x5991AA8b650D8d58a57663C18BEc57b8DD25CED9);
    address aliceToken = address(0xAC51066d7bEC65Dc4589368da368b212745d63E8);
    address vrfCoordinator = address(0xD7f86b4b8Cae7D942340FF628F82735b7a20893a);
    bytes32 keyHash = 0x8077df514608a09f83e4e8d300645594e5d7234665448ba83f51a50f842bd3d9;
    uint32 callbackGasLimit = 75_000;
    uint16 requestConfirmations = 3;
    uint32 houseFee = 5000; // 10%

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        raffleContract = new Raffle(
            subscriptionId, aliceToken, vrfCoordinator, keyHash, callbackGasLimit, requestConfirmations, houseFee
        );
        address raffleAdmin =0x1EaBbcadc09f5791E95EA0D2262389Ad34b15B35;
        raffleContract.assignAdminRole(raffleAdmin);
        vm.stopBroadcast();
    }
}