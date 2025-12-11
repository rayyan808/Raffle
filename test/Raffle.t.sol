// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "../src/Raffle.sol";

contract RaffleTest is Test {
    Raffle public Raffle;

    function setUp() public {
        Raffle = new Raffle();
        Raffle.setNumber(0);
    }

    function test_Increment() public {
        Raffle.increment();
        assertEq(Raffle.number(), 1);
    }

    function testFuzz_SetNumber(uint256 x) public {
        Raffle.setNumber(x);
        assertEq(Raffle.number(), x);
    }
}
