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
import {console} from "forge-std/console.sol";

contract RaffleTest is Test {
    Raffle public raffleContract;
    uint256 private subscriptionId;
    address owner = address(0xABCD);
    address user = address(0xBEEF);
    address user2 = address(0xFEEB);
    address user3 = address(0xCAFE);

    AliceToken aliceToken;
    VRFCoordinatorV2_5Mock vrfCoordinatorMock;

    // VRF Config
    bytes32 constant KEY_HASH = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    uint32 constant CALLBACK_GAS_LIMIT = 100000;
    uint16 constant REQUEST_CONFIRMATIONS = 3;

    // Mock VRF constants
    uint96 constant BASE_FEE = 0.25 ether;
    uint96 constant GAS_PRICE_LINK = 1e9;
    int256 constant WEI_PER_UNIT_LINK = 1e18;

    // Token constants
    uint256 constant ALICE_DECIMALS = 6;
    uint256 constant TICKET_PRICE = 10 * (10 ** ALICE_DECIMALS); // 10 ALICE with decimals
    uint256 constant ONE_HUNDRED_ALICE = 100 * (10 ** ALICE_DECIMALS);
    uint256 constant TWO_HUNDRED_ALICE = 200 * (10 ** ALICE_DECIMALS);

    uint256 constant HOUSE_FEE = 2500; // 25% in basis points

    function setUp() public {
        vm.startPrank(owner);

        // Deploy VRF Mock
        vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(BASE_FEE, GAS_PRICE_LINK, WEI_PER_UNIT_LINK);
        subscriptionId = vrfCoordinatorMock.createSubscription();
        vrfCoordinatorMock.fundSubscription(subscriptionId, 100 ether);

        // Deploy Token
        aliceToken = new AliceToken();

        // Deploy Raffle with new constructor parameters
        raffleContract = new Raffle(
            subscriptionId,
            address(aliceToken),
            address(vrfCoordinatorMock),
            KEY_HASH,
            CALLBACK_GAS_LIMIT,
            REQUEST_CONFIRMATIONS,
            HOUSE_FEE
        );

        vrfCoordinatorMock.addConsumer(subscriptionId, address(raffleContract));

        vm.stopPrank();
    }

    // ============ Constructor Tests ============

    function test_constructor_setsCorrectValues() public view {
        assertEq(address(raffleContract.aliceToken()), address(aliceToken));
        assertEq(raffleContract.subscriptionId(), subscriptionId);
        assertEq(raffleContract.keyHash(), KEY_HASH);
        assertEq(raffleContract.callbackGasLimit(), CALLBACK_GAS_LIMIT);
        assertEq(raffleContract.requestConfirmations(), REQUEST_CONFIRMATIONS);
        assertEq(raffleContract.houseFee(), HOUSE_FEE);
        assertEq(raffleContract.currentRaffleId(), 0);
        assertTrue(raffleContract.paused());
    }

    function test_constructor_revertsOnZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(Raffle.InvalidAddress.selector);
        new Raffle(
            subscriptionId,
            address(0),
            address(vrfCoordinatorMock),
            KEY_HASH,
            CALLBACK_GAS_LIMIT,
            REQUEST_CONFIRMATIONS,
            HOUSE_FEE
        );
        vm.stopPrank();
    }

    function test_constructor_revertsOnInvalidFee() public {
        vm.startPrank(owner);
        vm.expectRevert(Raffle.InvalidFee.selector);
        new Raffle(
            subscriptionId,
            address(aliceToken),
            address(vrfCoordinatorMock),
            KEY_HASH,
            CALLBACK_GAS_LIMIT,
            REQUEST_CONFIRMATIONS,
            5001 // Over 50% max
        );
        vm.stopPrank();
    }

    function test_startRaffle() public {
        vm.startPrank(owner);
        raffleContract.startRaffle(TICKET_PRICE, "generic_reward", 1, "winner_reward", 1);
        vm.stopPrank();

        assertEq(raffleContract.currentRaffleId(), 1);
        assertFalse(raffleContract.paused());

        Raffle.RaffleConfig memory config = raffleContract.getRaffleConfig(1);
        assertEq(config.ticketPrice, TICKET_PRICE);
        assertTrue(config.isActive);
    }

    function test_startRaffle_emitsEvent() public {
        vm.startPrank(owner);

        vm.expectEmit(true, false, false, true, address(raffleContract));
        emit Raffle.RaffleStarted(1, TICKET_PRICE);

        raffleContract.startRaffle(TICKET_PRICE, "generic_reward", 1, "winner_reward", 1);
        vm.stopPrank();
    }

    function test_startRaffle_revertsIfNotOwner() public {
        vm.prank(user);
        vm.expectRevert();
        raffleContract.startRaffle(TICKET_PRICE, "generic_reward", 1, "winner_reward", 1);
    }

    function test_startRaffle_revertsOnZeroTicketPrice() public {
        vm.prank(owner);
        vm.expectRevert(Raffle.InvalidTicketPrice.selector);
        raffleContract.startRaffle(0, "generic_reward", 1, "winner_reward", 1);
    }

    function test_stopRaffle_revertsWithNoParticipants() public {
        vm.startPrank(owner);
        raffleContract.startRaffle(TICKET_PRICE, "generic_reward", 1, "winner_reward", 1);

        vm.expectRevert(Raffle.NoParticipants.selector);
        raffleContract.stopRaffle();
        vm.stopPrank();
    }

    function test_stopRaffle_pausesContract() public {
        _setupRaffleWithDeposit(user, TICKET_PRICE, ONE_HUNDRED_ALICE);

        vm.prank(owner);
        raffleContract.stopRaffle();

        assertTrue(raffleContract.paused());
        assertTrue(raffleContract.awaitingVRF());
    }

    function test_stopRaffle_preventsDepositsAfterStop() public {
        _setupRaffleWithDeposit(user, TICKET_PRICE, ONE_HUNDRED_ALICE);

        vm.prank(owner);
        raffleContract.stopRaffle();

        vm.prank(user2);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        raffleContract.deposit(TICKET_PRICE);
    }

    function test_deposit_createsTickets() public {
        vm.prank(owner);
        raffleContract.startRaffle(TICKET_PRICE, "generic_reward", 1, "winner_reward", 1);
        _mintAndApprove(user, ONE_HUNDRED_ALICE);

        vm.prank(user);
        raffleContract.deposit(ONE_HUNDRED_ALICE);

        assertEq(raffleContract.getTicketCount(1), 10);
        assertEq(raffleContract.getUserTickets(1, user), 10);
        assertEq(raffleContract.getPrizePool(1), ONE_HUNDRED_ALICE);
    }

    function test_deposit_emitsEvents() public {
        vm.prank(owner);
        raffleContract.startRaffle(TICKET_PRICE, "generic_reward", 1, "winner_reward", 1);
        _mintAndApprove(user, ONE_HUNDRED_ALICE);

        vm.expectEmit(true, true, false, true, address(raffleContract));
        emit Raffle.Deposit(user, 1, ONE_HUNDRED_ALICE, 10);

        vm.expectEmit(true, true, false, true, address(raffleContract));
        emit Raffle.GenericRewardClaimed(user, 1, "generic_reward", 1);

        vm.prank(user);
        raffleContract.deposit(ONE_HUNDRED_ALICE);
    }

    function test_deposit_revertsOnInvalidAmount() public {
        vm.prank(owner);
        raffleContract.startRaffle(TICKET_PRICE, "generic_reward", 1, "winner_reward", 1);

        uint256 invalidAmount = TICKET_PRICE + 1; // Not a multiple of ticket price
        _mintAndApprove(user, invalidAmount);

        vm.prank(user);
        vm.expectRevert(Raffle.InvalidAmount.selector);
        raffleContract.deposit(invalidAmount);
    }

    function test_deposit_revertsOnZeroAmount() public {
        vm.prank(owner);
        raffleContract.startRaffle(TICKET_PRICE, "generic_reward", 1, "winner_reward", 1);

        vm.prank(user);
        vm.expectRevert(Raffle.InvalidAmount.selector);
        raffleContract.deposit(0);
    }

    function test_genericReward_onlyClaimedOnce() public {
        vm.prank(owner);
        raffleContract.startRaffle(TICKET_PRICE, "generic_reward", 1, "winner_reward", 1);
        _mintAndApprove(user, TWO_HUNDRED_ALICE);

        vm.prank(user);
        raffleContract.deposit(ONE_HUNDRED_ALICE);

        assertTrue(raffleContract.hasClaimedGeneric(1, user));

        vm.recordLogs();
        vm.prank(user);
        raffleContract.deposit(ONE_HUNDRED_ALICE);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 rewardEventSignature = keccak256("GenericRewardClaimed(address,uint256,string,uint8)");

        for (uint256 i = 0; i < logs.length; i++) {
            assertNotEq(
                logs[i].topics[0], rewardEventSignature, "GenericRewardClaimed should not be emitted on second deposit"
            );
        }
    }

    /**
     *
     * Winner Selection Testing
     */
    function test_winnerSelection_setsWinner() public {
        _setupRaffleWithDeposit(user, TICKET_PRICE, ONE_HUNDRED_ALICE);

        vm.prank(owner);
        raffleContract.stopRaffle();

        vrfCoordinatorMock.fulfillRandomWords(1, address(raffleContract));

        address winner = raffleContract.getWinner(1);
        assertEq(winner, user);
        assertFalse(raffleContract.awaitingVRF());
    }

    function test_winnerSelection_emitsEvent() public {
        _setupRaffleWithDeposit(user, TICKET_PRICE, ONE_HUNDRED_ALICE);

        vm.prank(owner);
        raffleContract.stopRaffle();

        vm.recordLogs();
        vrfCoordinatorMock.fulfillRandomWords(1, address(raffleContract));

        Vm.Log[] memory logs = vm.getRecordedLogs();
        (address winner, uint256 raffleId, uint256 winnerIndex) = _getWinnerSelectedEvent(logs);

        assertEq(winner, user);
        assertEq(raffleId, 1);
        assertTrue(winnerIndex < 10); // Must be valid index
    }

    /*
    * Claim Winner Reward Tests
    */

    function test_claimWinnerReward_transfersPrize() public {
        _setupRaffleWithDeposit(user, TICKET_PRICE, ONE_HUNDRED_ALICE);

        vm.prank(owner);
        raffleContract.stopRaffle();

        vrfCoordinatorMock.fulfillRandomWords(1, address(raffleContract));

        uint256 expectedPrize = ONE_HUNDRED_ALICE - (ONE_HUNDRED_ALICE * HOUSE_FEE / 10000);
        uint256 balanceBefore = aliceToken.balanceOf(user);

        vm.prank(user);
        raffleContract.claimWinnerReward(1);

        assertEq(aliceToken.balanceOf(user), balanceBefore + expectedPrize);
    }

    function test_claimWinnerReward_emitsEvent() public {
        _setupRaffleWithDeposit(user, TICKET_PRICE, ONE_HUNDRED_ALICE);

        vm.prank(owner);
        raffleContract.stopRaffle();

        vrfCoordinatorMock.fulfillRandomWords(1, address(raffleContract));

        uint256 expectedPrize = ONE_HUNDRED_ALICE - (ONE_HUNDRED_ALICE * HOUSE_FEE / 10000);

        vm.expectEmit(true, true, false, true, address(raffleContract));
        emit Raffle.WinnerRewardClaimed(user, 1, "winner_reward", 1, expectedPrize);

        vm.prank(user);
        raffleContract.claimWinnerReward(1);
    }

    function test_claimWinnerReward_revertsIfNotWinner() public {
        _setupRaffleWithDeposit(user, TICKET_PRICE, ONE_HUNDRED_ALICE);

        vm.prank(owner);
        raffleContract.stopRaffle();

        vrfCoordinatorMock.fulfillRandomWords(1, address(raffleContract));

        vm.prank(user2);
        vm.expectRevert(Raffle.NotWinner.selector);
        raffleContract.claimWinnerReward(1);
    }

    function test_claimWinnerReward_revertsIfAlreadyClaimed() public {
        _setupRaffleWithDeposit(user, TICKET_PRICE, ONE_HUNDRED_ALICE);

        vm.prank(owner);
        raffleContract.stopRaffle();

        vrfCoordinatorMock.fulfillRandomWords(1, address(raffleContract));

        vm.prank(user);
        raffleContract.claimWinnerReward(1);

        vm.prank(user);
        vm.expectRevert(Raffle.RewardAlreadyClaimed.selector);
        raffleContract.claimWinnerReward(1);
    }

    function test_claimWinnerReward_revertsIfRaffleStillActive() public {
        vm.prank(owner);
        raffleContract.startRaffle(TICKET_PRICE, "generic_reward", 1, "winner_reward", 1);

        vm.prank(user);
        vm.expectRevert(Raffle.NotWinner.selector);
        raffleContract.claimWinnerReward(1);
    }

    /*
    * House Fee Tests
    */

    function test_houseFee_accumulatesCorrectly() public {
        _setupRaffleWithDeposit(user, TICKET_PRICE, ONE_HUNDRED_ALICE);

        vm.prank(owner);
        raffleContract.stopRaffle();

        vrfCoordinatorMock.fulfillRandomWords(1, address(raffleContract));

        vm.prank(user);
        raffleContract.claimWinnerReward(1);

        uint256 expectedFee = ONE_HUNDRED_ALICE * HOUSE_FEE / 10000;
        assertEq(raffleContract.accumulatedHouseFees(), expectedFee);
    }

    function test_withdrawHouseFees() public {
        _setupRaffleWithDeposit(user, TICKET_PRICE, ONE_HUNDRED_ALICE);

        vm.prank(owner);
        raffleContract.stopRaffle();

        vrfCoordinatorMock.fulfillRandomWords(1, address(raffleContract));

        vm.prank(user);
        raffleContract.claimWinnerReward(1);

        uint256 expectedFee = ONE_HUNDRED_ALICE * HOUSE_FEE / 10000;
        address feeRecipient = address(0xFEE);

        vm.prank(owner);
        raffleContract.withdrawHouseFees(feeRecipient);

        assertEq(aliceToken.balanceOf(feeRecipient), expectedFee);
        assertEq(raffleContract.accumulatedHouseFees(), 0);
    }

    function test_withdrawHouseFees_revertsIfNothingToWithdraw() public {
        vm.prank(owner);
        vm.expectRevert(Raffle.NothingToWithdraw.selector);
        raffleContract.withdrawHouseFees(address(0xFEE));
    }

    function test_withdrawHouseFees_revertsOnZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(Raffle.InvalidAddress.selector);
        raffleContract.withdrawHouseFees(address(0));
    }

    function test_setHouseFee() public {
        vm.prank(owner);

        vm.expectEmit(false, false, false, true, address(raffleContract));
        emit Raffle.HouseFeeUpdated(HOUSE_FEE, 1000);

        raffleContract.setHouseFee(1000); //10%

        assertEq(raffleContract.houseFee(), 1000);
    }

    function test_setHouseFee_revertsIfTooHigh() public {
        vm.prank(owner);
        vm.expectRevert(Raffle.InvalidFee.selector);
        raffleContract.setHouseFee(5001); // Over 50%
    }

    /*
    * Inject Capital Tests
    */

    function test_injectCapital() public {
        vm.prank(owner);
        raffleContract.startRaffle(TICKET_PRICE, "generic_reward", 1, "winner_reward", 1);

        uint256 injectAmount = 500 * (10 ** ALICE_DECIMALS);
        _mintAndApprove(user2, injectAmount);

        vm.expectEmit(true, true, false, true, address(raffleContract));
        emit Raffle.CapitalInjected(user2, 1, injectAmount);

        vm.prank(user2);
        raffleContract.injectCapital(injectAmount);

        assertEq(raffleContract.getPrizePool(1), injectAmount);
        // Injector should NOT have tickets, were just alice admins increasing the pot
        assertEq(raffleContract.getUserTickets(1, user2), 0);
    }

    function test_injectCapital_revertsOnZeroAmount() public {
        vm.prank(owner);
        raffleContract.startRaffle(TICKET_PRICE, "generic_reward", 1, "winner_reward", 1);

        vm.prank(user);
        vm.expectRevert(Raffle.InvalidAmount.selector);
        raffleContract.injectCapital(0);
    }

    /*
    * Update VRF Config Tests
    */

    function test_updateVRFConfig() public {
        bytes32 newKeyHash = bytes32(uint256(123));
        uint32 newGasLimit = 200000;
        uint16 newConfirmations = 5;

        vm.prank(owner);
        raffleContract.updateVRFConfig(subscriptionId, newKeyHash, newGasLimit, newConfirmations);

        assertEq(raffleContract.keyHash(), newKeyHash);
        assertEq(raffleContract.callbackGasLimit(), newGasLimit);
        assertEq(raffleContract.requestConfirmations(), newConfirmations);
    }

    /**
     * Test multiple raffles and claim succession, ensuring state isolation between raffles
     */
    function test_multipleRaffles_isolatedState() public {
        // Raffle 1
        _setupRaffleWithDeposit(user, TICKET_PRICE, ONE_HUNDRED_ALICE); //10 Tickets
        vm.prank(owner);
        raffleContract.stopRaffle();
        vrfCoordinatorMock.fulfillRandomWords(1, address(raffleContract));

        // Raffle 2
        _setupRaffleWithDeposit(user2, TICKET_PRICE, TWO_HUNDRED_ALICE); //20 tickets
        vm.prank(owner);
        raffleContract.stopRaffle();
        vrfCoordinatorMock.fulfillRandomWords(2, address(raffleContract));

        assertEq(raffleContract.getTicketCount(1), 10);
        assertEq(raffleContract.getTicketCount(2), 20);

        assertEq(raffleContract.getUserTickets(1, user), 10);
        assertEq(raffleContract.getUserTickets(1, user2), 0);

        assertEq(raffleContract.getUserTickets(2, user2), 20);
        assertEq(raffleContract.getUserTickets(2, user), 0);
    }

    function test_multipleRaffles_winnersCanClaimSeparately() public {
        _setupRaffleWithDeposit(user, TICKET_PRICE, ONE_HUNDRED_ALICE);
        vm.prank(owner);
        raffleContract.stopRaffle();
        vrfCoordinatorMock.fulfillRandomWords(1, address(raffleContract));

        vm.prank(owner);
        raffleContract.startRaffle(TICKET_PRICE, "reward2", 2, "winner2", 2);

        uint256 deposit2 = 50 * (10 ** ALICE_DECIMALS);
        _mintAndApprove(user2, deposit2);
        vm.prank(user2);
        raffleContract.deposit(deposit2);

        vm.prank(owner);
        raffleContract.stopRaffle();
        vrfCoordinatorMock.fulfillRandomWords(2, address(raffleContract));

        vm.prank(user);
        raffleContract.claimWinnerReward(1);

        vm.prank(user2);
        raffleContract.claimWinnerReward(2);

        Raffle.RaffleConfig memory config1 = raffleContract.getRaffleConfig(1);
        Raffle.RaffleConfig memory config2 = raffleContract.getRaffleConfig(2);
        assertTrue(config1.winnerClaimed);
        assertTrue(config2.winnerClaimed);
    }

    /**
     * Test startRaffle and emergencyPause reverts while awaiting VRF
     */
    function test_startRaffle_revertsWhileAwaitingVRF() public {
        _setupRaffleWithDeposit(user, TICKET_PRICE, ONE_HUNDRED_ALICE);

        vm.prank(owner);
        raffleContract.stopRaffle();

        // Try to start new raffle before VRF callback
        vm.prank(owner);
        vm.expectRevert(Raffle.VRFRequestPending.selector);
        raffleContract.startRaffle(TICKET_PRICE, "new", 1, "new", 1);
    }

    function test_emergencyPause() public {
        vm.prank(owner);
        raffleContract.startRaffle(TICKET_PRICE, "generic_reward", 1, "winner_reward", 1);

        vm.prank(owner);
        raffleContract.emergencyPause();

        assertTrue(raffleContract.paused());
    }

    function test_emergencyPause_revertsWhileAwaitingVRF() public {
        _setupRaffleWithDeposit(user, TICKET_PRICE, ONE_HUNDRED_ALICE);

        vm.prank(owner);
        raffleContract.stopRaffle();

        vm.prank(owner);
        vm.expectRevert(Raffle.VRFRequestPending.selector);
        raffleContract.emergencyPause();
    }

    /*
    * Utility Function Tests
    */

    function test_calculateWinnerPrize() public {
        vm.prank(owner);
        raffleContract.startRaffle(TICKET_PRICE, "generic_reward", 1, "winner_reward", 1);
        _mintAndApprove(user, ONE_HUNDRED_ALICE);

        vm.prank(user);
        raffleContract.deposit(ONE_HUNDRED_ALICE);

        uint256 expectedPrize = ONE_HUNDRED_ALICE - (ONE_HUNDRED_ALICE * HOUSE_FEE / 10000);
        assertEq(raffleContract.calculateWinnerPrize(1), expectedPrize);
    }

    function test_getTicketPriceFormatted() public {
        vm.prank(owner);
        raffleContract.startRaffle(TICKET_PRICE, "generic_reward", 1, "winner_reward", 1);

        assertEq(raffleContract.getTicketPriceFormatted(1), 10); // 10 ALICE without decimals
    }

    /**
     * Internal Testing Helper Functions
     */
    function _mintAndApprove(address to, uint256 amount) internal {
        vm.startPrank(to);
        aliceToken.mint(to, amount);
        aliceToken.approve(address(raffleContract), amount);
        vm.stopPrank();
    }

    function _setupRaffleWithDeposit(address depositor, uint256 ticketPrice, uint256 amount) internal {
        vm.prank(owner);
        raffleContract.startRaffle(ticketPrice, "generic_reward", 1, "winner_reward", 1);

        _mintAndApprove(depositor, amount);

        vm.prank(depositor);
        raffleContract.deposit(amount);
    }

    function _getWinnerSelectedEvent(Vm.Log[] memory logs)
        internal
        pure
        returns (address winner, uint256 raffleId, uint256 winnerIndex)
    {
        bytes32 sig = keccak256("WinnerSelected(address,uint256,uint256)");

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == sig) {
                winner = address(uint160(uint256(logs[i].topics[1])));
                raffleId = uint256(logs[i].topics[2]);
                winnerIndex = abi.decode(logs[i].data, (uint256));
                return (winner, raffleId, winnerIndex);
            }
        }
        revert("WinnerSelected event not found");
    }
}
