// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.5.0
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

///@title A Raffle System that rewards ALICE and in-game NFTs
///@author Rayyan Jafri rayyan808@gmail.com

contract Raffle is Pausable, VRFConsumerBaseV2Plus {
    /**
     * Notes: Transfer Ownership of the proxy to a multi-sig
     * Proxy owner cannot interact with logic contracts, so important to assign it to another wallet avoid confusion
     */
    /**
     * @dev Sepolia Configs
     */
    uint256 subscriptionId;
    address vrfCoordinator = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    bytes32 keyHash = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    uint32 callbackGasLimit = 40000;
    uint16 requestConfirmations = 3;
    uint32 numWords = 1;

    uint256 public currentPool;
    ///@notice Track each users number of deposits
    mapping(address => uint256) private deposits;

    ///@notice Track each users claimed rewards
    mapping(address => uint8) private claimedRewards;

    ///@notice Track each winner thats claimed
    mapping(address => uint8) private claimedWinners;

    ///@notice Winners
    mapping(uint8 => address) public winners;

    ///@notice Raffle Tickets
    address[] members;

    ///@notice raffleActive
    bool public raffleActive = false;

    ///@notice Raffle ID
    uint8 private raffleId = 0;

    ///@notice Generic Reward CRC2 Name
    string private genericReward = "prototype_name";

    ///@notice Generic Reward Amount
    uint8 private genericRewardAmount = 1;

    ///@notice Winner Reward CRC2 Name
    string private winnerReward = "prototype_name";

    ///@notice Winner Reward Amount
    uint8 private winnerRewardAmount = 1;

    ///@notice Cost of Raffle Ticket in ALICE
    uint256 rafflePrice = 10;

    ///@notice The percentage of total raffle going to MNA in basis points (1% = 100 bps)
    uint256 private houseFee = 2500; //25%

    IERC20 private aliceToken;
    uint256 private constant ALICE_DECIMALS = 6;

    error NotEnoughDeposit();
    error YouAreNotWinner();
    error RewardAlreadyClaimed();
    error RaffleNotActive();
    error PendingWinner();
    /// @custom:security-contact rayyan808@gmail.com

    ///@notice Reward CRC2 Event
    ///@param wallet The wallet
    ///@param token The in-game reward token
    ///@param amount The amount of reward token
    event RewardCRC2(address indexed wallet, string token, uint8 indexed amount);

    ///@notice Winner Selected Event
    ///@param winner The winner address
    ///@param raffleId The raffle ID
    event WinnerSelected(address indexed winner, uint8 indexed raffleId);

    ///@notice Constructor
    ///@param _aliceToken Address of the Alice ERC20 Token
    constructor(uint256 _subscriptionId, address _aliceToken, address _vrfCoordinator)
        VRFConsumerBaseV2Plus(_vrfCoordinator)
    {
        require(address(_aliceToken) != address(0), "Token address is invalid");
        subscriptionId = _subscriptionId;
        vrfCoordinator = _vrfCoordinator;
        aliceToken = IERC20(_aliceToken);
        pause();
    }

    ///@notice Set the house fee
    ///@param percentage The percentage value in whole number
    function setFee(uint8 percentage) public onlyOwner {
        houseFee = percentage;
    }

    ///@notice Deposit Pre-determined amount
    function deposit(uint256 amount) public whenNotPaused {
        if (amount % rafflePrice != 0) {
            revert NotEnoughDeposit();
        }
        uint256 numberOfTickets = amount / rafflePrice;

        require(aliceToken.transferFrom(msg.sender, address(this), amount));

        currentPool += amount;
        for (uint256 i = 0; i < numberOfTickets; i += 1) {
            members.push(msg.sender);
        }
        //prevent double spending
        if (claimedRewards[msg.sender] < raffleId) {
            claimedRewards[msg.sender] = raffleId;
            emit RewardCRC2(msg.sender, genericReward, genericRewardAmount);
        }
    }
    ///@notice Claim Reward if winner, Only callable when Raffle is paused

    function claimReward() public whenPaused {
        if (winners[raffleId] != msg.sender) {
            revert YouAreNotWinner();
        }
        if (claimedRewards[msg.sender] == raffleId) {
            revert RewardAlreadyClaimed();
        }
        claimedRewards[msg.sender] = raffleId;
        emit RewardCRC2(msg.sender, winnerReward, winnerRewardAmount);
        uint256 prize = currentPool;
        currentPool = 0;
        require(aliceToken.transferFrom(address(this), msg.sender, prize - (prize * houseFee) / 10000));
    }

    ///@notice Callback function used by VRF Coordinator
    ///@param randomWords The array of random words generated

    function fulfillRandomWords(uint256, uint256[] calldata randomWords) internal override {
        uint256 winnerIndex = (randomWords[0] % members.length);
        emit WinnerSelected(members[winnerIndex], raffleId);
        winners[raffleId] = members[winnerIndex];
    }

    ///@notice Start accepting deposits
    ///@param _rafflePrice The amount of the CRC2 Token reward
    ///@param _genericReward The amount of the CRC2 Token reward to all participants
    ///@param _genericAmount The amount of the CRC2 Token reward to all participants
    ///@param _winnerReward The name of the CRC2 Token to reward the winner
    ///@param _winnerAmount The amount of the CRC2 Token reward to the winner
    function startRaffle(
        uint256 _rafflePrice,
        string calldata _genericReward,
        uint8 _genericAmount,
        string calldata _winnerReward,
        uint8 _winnerAmount
    ) public onlyOwner whenPaused {
        raffleId++;
        rafflePrice = _rafflePrice;
        genericReward = _genericReward;
        genericRewardAmount = _genericAmount;
        winnerReward = _winnerReward;
        winnerRewardAmount = _winnerAmount;
        unpause();
    }

    ///@notice Stop accepting deposits
    function stopRaffle() public onlyOwner whenNotPaused {
        //Call VRF
        s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );
        pause();
    }

    ///@notice Inject Capital into the Raffle Pool
    ///@param amount The amount of ALICE to inject
    ///@dev Anyone can inject, they are not considered for the raffle. This is essentially for marketing purposes only

    function injectCapital(uint256 amount) public whenNotPaused {
        require(aliceToken.transferFrom(msg.sender, address(this), amount));
        currentPool += amount;
    }

    ///@notice Pause the Raffle
    function pause() public onlyOwner {
        _pause();
    }
    ///@notice Unpause the Raffle

    function unpause() public onlyOwner {
        _unpause();
    }
}
