// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.5.0
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "../src/Raffle.sol";
import {AliceToken} from "./AliceToken.sol";

contract RaffleTest is Test {
    Raffle public raffleContract;
    uint256 private subscriptionId = 1;
    address owner = address(0xABCD);
    AliceToken aliceToken;

    function setUp() public {
        vm.startPrank(owner);
        raffleContract = new Raffle(subscriptionId, address(aliceToken));
        aliceToken = new AliceToken();
        //Mimic Proxy initialization
        vm.stopPrank();
    }

    function test_startRaffle() public {
        vm.startPrank(owner);
        raffleContract.startRaffle(10, "generic_reward", 1, "winner_reward", 1);
        assertEq(raffleContract.paused(), false);
        vm.stopPrank();
    }

    function test_stopRaffle() public {
        vm.startPrank(owner);
        raffleContract.startRaffle(10, "generic_reward", 1, "winner_reward", 1);
        raffleContract.stopRaffle();
        assertEq(raffleContract.paused(), true);
        vm.stopPrank();
    }

    function testFuzz_SetNumber(uint256 x) public {
        //   raffleContract.setNumber(x);
        //   assertEq(raffleContract.number(), x);
    }
}
