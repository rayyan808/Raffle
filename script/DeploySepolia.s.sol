// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.5.0
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";

//Sepolia subscription id:
contract RaffleScript is Script {
    Raffle raffleContract;
    uint256 subscriptionId = 40808765163228647507612850789173005084771641088052623735432322629146608652110;
    address owner = address(0x5991AA8b650D8d58a57663C18BEc57b8DD25CED9);
    address aliceToken = address(0x42dA9C5F5B727E2F9dA13A90754Cc4ED1D30e544);
    address vrfCoordinator = address(0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B);
    bytes32 keyHash = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
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
/*
forge verify-contract \
  --chain-id 11155111 \
  --num-of-optimizations 200 \
  --compiler-version v0.8.19; \
  0xc72A50301aD78f6D1Eba542Eb1d0D239B6121334 \
  src/Raffle.sol:Raffle \
  --constructor-args $(cast abi-encode "constructor(uint256,address,address,bytes32,uint32,uint16,uint256" 40808765163228647507612850789173005084771641088052623735432322629146608652110 0x8026d12157a8d8685B79e997882a553349273AB4 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae 100000 3 1)
  */
