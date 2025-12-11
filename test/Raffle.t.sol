// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.5.0
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Raffle} from "../src/Raffle.sol";
import {AliceToken} from "./AliceToken.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {Vm} from "forge-std/Vm.sol";

contract RaffleTest is Test {
    Raffle public raffleContract;
    uint256 private subscriptionId = 58595570991177481795909977511999548198401963399030403642029578792317275928374;
    address owner = address(0xABCD);
    AliceToken aliceToken;
    VRFCoordinatorV2_5Mock vrfCoordinatorMock;

    function setUp() public {
        vm.startPrank(owner);
        vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(0, 0, 0);
        vrfCoordinatorMock.createSubscription();
        vrfCoordinatorMock.fundSubscription(subscriptionId, 1 ether);
        aliceToken = new AliceToken();
        raffleContract = new Raffle(subscriptionId, address(aliceToken), address(vrfCoordinatorMock));
        vrfCoordinatorMock.addConsumer(subscriptionId, address(raffleContract));
        //Mimic Proxy initialization
        vm.stopPrank();
    }

    function test_startRaffle() public {
        vm.startPrank(owner);
        raffleContract.startRaffle(10, "generic_reward", 1, "winner_reward", 1);
        vm.stopPrank();
    }

    function test_stopRaffle() public {
        vm.startPrank(owner);
        raffleContract.startRaffle(10, "generic_reward", 1, "winner_reward", 1);
        raffleContract.stopRaffle();
        vm.stopPrank();
        address user = address(0xBEEF);
        vm.prank(user);
        vm.expectRevert(Pausable.EnforcedPause.selector); //Cannot deposit after raffle ends
        raffleContract.deposit(10);

        vm.expectRevert(Raffle.YouAreNotWinner.selector); //Cannot claim a reward if you didnt win
        raffleContract.claimReward();
    }

    function test_genericRewards() public {
        vm.prank(owner);
        raffleContract.startRaffle(10, "generic_reward", 1, "winner_reward", 1);

        address user = address(0xBEEF);
        vm.startPrank(user);
        aliceToken.mint(user, 100);
        aliceToken.approve(address(raffleContract), 100);

        vm.expectEmit(true, true, false, true, address(aliceToken));
        emit IERC20.Transfer(user, address(raffleContract), 100);

        vm.expectEmit(true, true, false, true, address(raffleContract));
        emit Raffle.RewardCRC2(user, "generic_reward", 1);

        raffleContract.deposit(100);
        vm.stopPrank();
    }

    function test_noRewardOnSecondDeposit() public {
        vm.prank(owner);
        raffleContract.startRaffle(10, "generic_reward", 1, "winner_reward", 1);

        address user = address(0xBEEF);
        vm.startPrank(user);
        aliceToken.mint(user, 200);
        aliceToken.approve(address(raffleContract), 200);

        // First deposit - should emit RewardCRC2
        raffleContract.deposit(100);

        // Start recording logs for second deposit
        vm.recordLogs();

        // Second deposit - should NOT emit RewardCRC2
        raffleContract.deposit(100);

        // Get recorded logs
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Check that RewardCRC2 was not emitted
        bytes32 rewardEventSignature = keccak256("RewardCRC2(address,string,uint256)");

        for (uint256 i = 0; i < logs.length; i++) {
            assertNotEq(logs[i].topics[0], rewardEventSignature, "RewardCRC2 should not be emitted on second deposit");
        }

        vm.stopPrank();
    }

    function testFuzz_SetNumber(uint256 x) public {
        //   raffleContract.setNumber(x);
        //   assertEq(raffleContract.number(), x);
    }
}
