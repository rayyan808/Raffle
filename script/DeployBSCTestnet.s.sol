// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.5.0
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";

//Sepolia subscription id: 40808765163228647507612850789173005084771641088052623735432322629146608652110
//BSC subscription id: 56945295715440302141806613071924181320794514565969974217977404289389416217632
contract RaffleScript is Script {
    Raffle raffleContract;
    uint256 subscriptionId = 56945295715440302141806613071924181320794514565969974217977404289389416217632;
    address owner = address(0x5991AA8b650D8d58a57663C18BEc57b8DD25CED9);
    address aliceToken = address(0xfF48145A7A869Cb19252074CF83D97f1542c3268);
    address vrfCoordinator = address(0xDA3b641D438362C440Ac5458c57e00a712b66700);
    bytes32 keyHash = 0x8596b430971ac45bdf6088665b9ad8e8630c9d5049ab54b14dff711bee7c0e26;
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
