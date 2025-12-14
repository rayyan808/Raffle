// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.5.0
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";

//Sepolia subscription id: 40808765163228647507612850789173005084771641088052623735432322629146608652110
contract RaffleScript is Script {
    Raffle raffleContract;
    uint256 subscriptionId = 58595570991177481795909977511999548198401963399030403642029578792317275928374;
    address owner = address(0xABCD);
    address aliceToken = address(0x1234);
    address vrfCoordinator = address(0x5678);
    bytes32 keyHash = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    uint32 callbackGasLimit = 100_000;
    uint16 requestConfirmations = 3;
    uint32 numWords = 1;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        raffleContract = new Raffle(
            subscriptionId, aliceToken, vrfCoordinator, keyHash, callbackGasLimit, requestConfirmations, numWords
        );

        vm.stopBroadcast();
    }
}
