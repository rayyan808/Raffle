// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.5.0
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/// @title A Raffle System that rewards ALICE and in-game NFTs
/// @author Rayyan Jafri rayyan808@gmail.com
/// @notice This contract implements a fair raffle system using Chainlink VRF for randomness
/// @custom:security-contact rayyan808@gmail.com

contract Raffle is Pausable, ReentrancyGuard, VRFConsumerBaseV2Plus {
    // ============ Constants ============

    /// @notice Basis points denominator (100% = 10000)
    uint256 private constant BASIS_POINTS = 10000;

    /// @notice Maximum house fee in basis points (50%)
    uint256 private constant MAX_HOUSE_FEE = 5000;

    /// @notice ALICE token decimals
    uint256 private constant ALICE_DECIMALS = 6;

    // ============ Immutables ============

    /// @notice The ALICE ERC20 token
    IERC20 public immutable aliceToken;

    // ============ VRF Configuration ============

    /// @notice Chainlink VRF subscription ID
    uint256 public subscriptionId;

    /// @notice Chainlink VRF key hash
    bytes32 public keyHash;

    /// @notice Callback gas limit for VRF
    uint32 public callbackGasLimit;

    /// @notice Number of confirmations for VRF
    uint16 public requestConfirmations;

    /// @notice Number of random words to request
    uint32 private constant NUM_WORDS = 1;

    // ============ Raffle State ============

    /// @notice Current raffle ID (starts at 1)
    uint256 public currentRaffleId;

    /// @notice Tracks if we're waiting for VRF response
    bool public awaitingVRF;

    /// @notice Pending VRF request ID
    uint256 private pendingRequestId;

    /// @notice The percentage of total raffle going to house in basis points
    uint256 public houseFee;

    /// @notice Accumulated house fees available for withdrawal
    uint256 public accumulatedHouseFees;

    // ============ Raffle Configuration Per Raffle ============

    struct RaffleConfig {
        uint256 ticketPrice;
        string genericReward;
        uint8 genericRewardAmount;
        string winnerReward;
        uint8 winnerRewardAmount;
        uint256 prizePool;
        address winner;
        bool winnerClaimed;
        bool isActive;
    }

    /// @notice Configuration for each raffle
    mapping(uint256 => RaffleConfig) public raffles;

    /// @notice Raffle tickets for each raffle (raffleId => participants)
    mapping(uint256 => address[]) private raffleTickets;

    /// @notice Track claimed generic rewards per raffle (raffleId => user => claimed)
    mapping(uint256 => mapping(address => bool)) private hasClaimedGenericReward;

    /// @notice Track user ticket count per raffle (raffleId => user => count)
    mapping(uint256 => mapping(address => uint256)) public userTicketCount;

    // ============ Errors ============

    error InvalidAmount();
    error InvalidTicketPrice();
    error NotWinner();
    error RewardAlreadyClaimed();
    error RaffleNotActive();
    error RaffleStillActive();
    error NoParticipants();
    error VRFRequestPending();
    error InvalidVRFRequest();
    error InvalidFee();
    error NothingToWithdraw();
    error InvalidAddress();
    error TransferFailed();

    // ============ Events ============

    /// @notice Emitted when a user deposits and receives tickets
    /// @param user The depositor's address
    /// @param raffleId The raffle ID
    /// @param amount The amount deposited
    /// @param ticketCount Number of tickets received
    event Deposit(address indexed user, uint256 indexed raffleId, uint256 amount, uint256 ticketCount);

    /// @notice Emitted when a generic CRC2 reward is given
    /// @param wallet The recipient wallet
    /// @param raffleId The raffle ID
    /// @param token The in-game reward token name
    /// @param amount The amount of reward token
    event GenericRewardClaimed(address indexed wallet, uint256 indexed raffleId, string token, uint8 amount);

    /// @notice Emitted when a winner claims their reward
    /// @param winner The winner's address
    /// @param raffleId The raffle ID
    /// @param token The winner reward token name
    /// @param tokenAmount The token amount
    /// @param prizeAmount The ALICE prize amount
    event WinnerRewardClaimed(
        address indexed winner, uint256 indexed raffleId, string token, uint8 tokenAmount, uint256 prizeAmount
    );

    /// @notice Emitted when a winner is selected
    /// @param winner The winner's address
    /// @param raffleId The raffle ID
    /// @param winnerIndex The index in the tickets array
    event WinnerSelected(address indexed winner, uint256 indexed raffleId, uint256 winnerIndex);

    /// @notice Emitted when a raffle starts
    /// @param raffleId The raffle ID
    /// @param ticketPrice Price per ticket
    event RaffleStarted(uint256 indexed raffleId, uint256 ticketPrice);

    /// @notice Emitted when a raffle stops and VRF is requested
    /// @param raffleId The raffle ID
    /// @param requestId The VRF request ID
    /// @param totalTickets Total tickets sold
    event RaffleStopped(uint256 indexed raffleId, uint256 requestId, uint256 totalTickets);

    /// @notice Emitted when capital is injected
    /// @param injector The address injecting capital
    /// @param raffleId The raffle ID
    /// @param amount The amount injected
    event CapitalInjected(address indexed injector, uint256 indexed raffleId, uint256 amount);

    /// @notice Emitted when house fees are withdrawn
    /// @param recipient The recipient address
    /// @param amount The amount withdrawn
    event HouseFeesWithdrawn(address indexed recipient, uint256 amount);

    /// @notice Emitted when house fee is updated
    /// @param oldFee The old fee in basis points
    /// @param newFee The new fee in basis points
    event HouseFeeUpdated(uint256 oldFee, uint256 newFee);

    /// @notice Emitted when VRF config is updated
    event VRFConfigUpdated(
        uint256 subscriptionId, bytes32 keyHash, uint32 callbackGasLimit, uint16 requestConfirmations
    );

    // ============ Constructor ============

    /// @notice Initialize the Raffle contract
    /// @param _subscriptionId Chainlink VRF subscription ID
    /// @param _aliceToken Address of the ALICE ERC20 token
    /// @param _vrfCoordinator Address of the VRF Coordinator
    /// @param _keyHash VRF key hash
    /// @param _callbackGasLimit Gas limit for VRF callback
    /// @param _requestConfirmations Number of confirmations for VRF
    /// @param _houseFee Initial house fee in basis points
    constructor(
        uint256 _subscriptionId,
        address _aliceToken,
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint32 _callbackGasLimit,
        uint16 _requestConfirmations,
        uint256 _houseFee
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        if (_aliceToken == address(0)) revert InvalidAddress();
        if (_houseFee > MAX_HOUSE_FEE) revert InvalidFee();

        aliceToken = IERC20(_aliceToken);
        subscriptionId = _subscriptionId;
        keyHash = _keyHash;
        callbackGasLimit = _callbackGasLimit;
        requestConfirmations = _requestConfirmations;
        houseFee = _houseFee;

        // Start paused, no active raffle
        _pause();
    }

    // ============ User Functions ============

    /// @notice Deposit ALICE tokens to receive raffle tickets
    /// @param amount The amount of ALICE to deposit (must be multiple of ticket price)
    function deposit(uint256 amount) external whenNotPaused nonReentrant {
        RaffleConfig storage raffle = raffles[currentRaffleId];

        if (!raffle.isActive) revert RaffleNotActive();

        uint256 ticketPrice = raffle.ticketPrice;
        if (amount == 0 || amount % ticketPrice != 0) revert InvalidAmount();

        uint256 numberOfTickets = amount / ticketPrice;

        // Transfer tokens
        bool success = aliceToken.transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();

        // Update prize pool
        raffle.prizePool += amount;

        // Add tickets
        address[] storage tickets = raffleTickets[currentRaffleId];
        for (uint256 i = 0; i < numberOfTickets; i++) {
            tickets.push(msg.sender);
        }

        // Track user's ticket count
        userTicketCount[currentRaffleId][msg.sender] += numberOfTickets;

        emit Deposit(msg.sender, currentRaffleId, amount, numberOfTickets);

        // Award generic reward (once per raffle per user)
        if (!hasClaimedGenericReward[currentRaffleId][msg.sender]) {
            hasClaimedGenericReward[currentRaffleId][msg.sender] = true;
            emit GenericRewardClaimed(msg.sender, currentRaffleId, raffle.genericReward, raffle.genericRewardAmount);
        }
    }

    /// @notice Claim winner reward for a specific raffle
    /// @param raffleId The raffle ID to claim for
    function claimWinnerReward(uint256 raffleId) external nonReentrant {
        RaffleConfig storage raffle = raffles[raffleId];

        // Must be the winner
        if (raffle.winner != msg.sender) revert NotWinner();

        // Must not have claimed already
        if (raffle.winnerClaimed) revert RewardAlreadyClaimed();

        // Raffle must be finished (not active and has a winner)
        if (raffle.isActive) revert RaffleStillActive();

        // Mark as claimed
        raffle.winnerClaimed = true;

        // Calculate prize
        uint256 totalPrize = raffle.prizePool;
        uint256 houseCut = (totalPrize * houseFee) / BASIS_POINTS;
        uint256 winnerPrize = totalPrize - houseCut;

        // Track house fees
        accumulatedHouseFees += houseCut;

        // Transfer prize to winner
        bool success = aliceToken.transfer(msg.sender, winnerPrize);
        if (!success) revert TransferFailed();

        emit WinnerRewardClaimed(msg.sender, raffleId, raffle.winnerReward, raffle.winnerRewardAmount, winnerPrize);
    }

    /// @notice Inject capital into the current raffle pool
    /// @param amount The amount of ALICE to inject
    /// @dev Anyone can inject capital for marketing/promotional purposes
    function injectCapital(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert InvalidAmount();

        RaffleConfig storage raffle = raffles[currentRaffleId];
        if (!raffle.isActive) revert RaffleNotActive();

        bool success = aliceToken.transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();

        raffle.prizePool += amount;

        emit CapitalInjected(msg.sender, currentRaffleId, amount);
    }

    // ============ Admin Functions ============

    /// @notice Start a new raffle
    /// @param _ticketPrice Price per ticket in ALICE (with decimals)
    /// @param _genericReward Name of generic CRC2 reward token
    /// @param _genericAmount Amount of generic reward
    /// @param _winnerReward Name of winner CRC2 reward token
    /// @param _winnerAmount Amount of winner reward
    function startRaffle(
        uint256 _ticketPrice,
        string calldata _genericReward,
        uint8 _genericAmount,
        string calldata _winnerReward,
        uint8 _winnerAmount
    ) external onlyOwner {
        if (awaitingVRF) revert VRFRequestPending();
        if (_ticketPrice == 0) revert InvalidTicketPrice();

        // Increment raffle ID
        currentRaffleId++;

        // Configure new raffle
        RaffleConfig storage raffle = raffles[currentRaffleId];
        raffle.ticketPrice = _ticketPrice;
        raffle.genericReward = _genericReward;
        raffle.genericRewardAmount = _genericAmount;
        raffle.winnerReward = _winnerReward;
        raffle.winnerRewardAmount = _winnerAmount;
        raffle.isActive = true;

        // Unpause to allow deposits
        _unpause();

        emit RaffleStarted(currentRaffleId, _ticketPrice);
    }

    /// @notice Stop the current raffle and request VRF for winner selection
    function stopRaffle() external onlyOwner whenNotPaused {
        RaffleConfig storage raffle = raffles[currentRaffleId];

        if (!raffle.isActive) revert RaffleNotActive();

        address[] storage tickets = raffleTickets[currentRaffleId];
        if (tickets.length == 0) revert NoParticipants();

        // Mark raffle as inactive
        raffle.isActive = false;

        // Set VRF pending flag
        awaitingVRF = true;

        // Request random number
        pendingRequestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );

        // Pause contract
        _pause();

        emit RaffleStopped(currentRaffleId, pendingRequestId, tickets.length);
    }

    /// @notice Set the house fee
    /// @param _houseFee The fee in basis points (100 = 1%, max 5000 = 50%)
    function setHouseFee(uint256 _houseFee) external onlyOwner {
        if (_houseFee > MAX_HOUSE_FEE) revert InvalidFee();

        uint256 oldFee = houseFee;
        houseFee = _houseFee;

        emit HouseFeeUpdated(oldFee, _houseFee);
    }

    /// @notice Update VRF configuration
    /// @param _subscriptionId New subscription ID
    /// @param _keyHash New key hash
    /// @param _callbackGasLimit New callback gas limit
    /// @param _requestConfirmations New request confirmations
    function updateVRFConfig(
        uint256 _subscriptionId,
        bytes32 _keyHash,
        uint32 _callbackGasLimit,
        uint16 _requestConfirmations
    ) external onlyOwner {
        subscriptionId = _subscriptionId;
        keyHash = _keyHash;
        callbackGasLimit = _callbackGasLimit;
        requestConfirmations = _requestConfirmations;

        emit VRFConfigUpdated(_subscriptionId, _keyHash, _callbackGasLimit, _requestConfirmations);
    }

    /// @notice Withdraw accumulated house fees
    /// @param recipient Address to receive the fees
    function withdrawHouseFees(address recipient) external onlyOwner nonReentrant {
        if (recipient == address(0)) revert InvalidAddress();

        uint256 amount = accumulatedHouseFees;
        if (amount == 0) revert NothingToWithdraw();

        accumulatedHouseFees = 0;

        bool success = aliceToken.transfer(recipient, amount);
        if (!success) revert TransferFailed();

        emit HouseFeesWithdrawn(recipient, amount);
    }

    /// @notice Emergency pause (only when not waiting for VRF)
    function emergencyPause() external onlyOwner {
        if (awaitingVRF) revert VRFRequestPending();
        _pause();
    }

    // ============ VRF Callback ============

    /// @notice Callback function used by VRF Coordinator
    /// @param requestId The VRF request ID
    /// @param randomWords The array of random words generated
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        // Verify this is the expected request
        if (requestId != pendingRequestId) revert InvalidVRFRequest();

        // Clear VRF pending flag
        awaitingVRF = false;

        address[] storage tickets = raffleTickets[currentRaffleId];
        uint256 winnerIndex = randomWords[0] % tickets.length;
        address winner = tickets[winnerIndex];

        // Record winner
        raffles[currentRaffleId].winner = winner;

        emit WinnerSelected(winner, currentRaffleId, winnerIndex);
    }

    // ============ View Functions ============

    /// @notice Get the number of tickets for a raffle
    /// @param raffleId The raffle ID
    /// @return The number of tickets
    function getTicketCount(uint256 raffleId) external view returns (uint256) {
        return raffleTickets[raffleId].length;
    }

    /// @notice Get raffle configuration
    /// @param raffleId The raffle ID
    /// @return config The raffle configuration
    function getRaffleConfig(uint256 raffleId) external view returns (RaffleConfig memory config) {
        return raffles[raffleId];
    }

    /// @notice Get the winner of a raffle
    /// @param raffleId The raffle ID
    /// @return The winner's address (address(0) if no winner yet)
    function getWinner(uint256 raffleId) external view returns (address) {
        return raffles[raffleId].winner;
    }

    /// @notice Get the prize pool for a raffle
    /// @param raffleId The raffle ID
    /// @return The prize pool amount
    function getPrizePool(uint256 raffleId) external view returns (uint256) {
        return raffles[raffleId].prizePool;
    }

    /// @notice Check if a user has claimed their generic reward for a raffle
    /// @param raffleId The raffle ID
    /// @param user The user's address
    /// @return Whether the user has claimed
    function hasClaimedGeneric(uint256 raffleId, address user) external view returns (bool) {
        return hasClaimedGenericReward[raffleId][user];
    }

    /// @notice Calculate the current ticket price in human-readable format
    /// @param raffleId The raffle ID
    /// @return The ticket price with decimals applied
    function getTicketPriceFormatted(uint256 raffleId) external view returns (uint256) {
        return raffles[raffleId].ticketPrice / (10 ** ALICE_DECIMALS);
    }

    /// @notice Get user's tickets for a specific raffle
    /// @param raffleId The raffle ID
    /// @param user The user's address
    /// @return The number of tickets the user has
    function getUserTickets(uint256 raffleId, address user) external view returns (uint256) {
        return userTicketCount[raffleId][user];
    }

    /// @notice Calculate potential winner prize after house fee
    /// @param raffleId The raffle ID
    /// @return The prize amount after fees
    function calculateWinnerPrize(uint256 raffleId) external view returns (uint256) {
        uint256 pool = raffles[raffleId].prizePool;
        uint256 houseCut = (pool * houseFee) / BASIS_POINTS;
        return pool - houseCut;
    }
}
