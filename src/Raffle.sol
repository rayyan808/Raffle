// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.5.0
pragma solidity ^0.8.27;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    ERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {
    ERC20PausableUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {
    Initializable
} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "chainlink-brownie-contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

///@title A Raffle System that rewards ALICE and in-game NFTs
///@author Rayyan Jafri rayyan808@gmail.com
contract MNARaffle is
    Initializable,
    ERC20Upgradeable,
    ERC20PausableUpgradeable,
    OwnableUpgradeable,
    VRFConsumerBaseV2Plus
{
    /**
    Notes: Transfer Ownership of the proxy to a multi-sig
    Proxy owner cannot interact with logic contracts, so important to assign it to another wallet avoid confusion */

    uint256 s_subscriptionId;
    address vrfCoordinator = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    bytes32 s_keyHash =
        0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
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
    uint8 private raffleID = 0;

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
    uint8 private houseFee = 2500; //25%

    ///@notice The starting time of the raffle
    uint256 public startTime;

    ///@notice The end time of the raffle
    uint256 public endTime;

    IERC20 private aliceToken;
    uint256 private constant ALICE_DECIMALS = 6;
    error NotEnoughDeposit();
    error YouAreNotWinner();
    error RaffleNotActive();
    error PendingWinner();
    /// @custom:security-contact rayyan808@gmail.com

    ///@notice Reward CRC2 Event
    ///@param wallet The wallet
    ///@param token The in-game reward token
    ///@param amount The amount of reward token
    event RewardCRC2(
        address indexed wallet,
        string token,
        uint8 indexed amount
    );
    /**
    unsafe .call() on the ERC20 
    */
    ///@notice Initialize the implementation contract
    ///@param initialOwner Owner of the contract
    ///@param _aliceToken Address of the Alice ERC20 Token
    function initialize(
        address initialOwner,
        address _aliceToken
    ) public initializer {
        require(address(_aliceToken) != address(0), "Token address is invalid");
        //_disableInitializers(); ??
        aliceToken = IERC20(_aliceToken);
        __ERC20_init("MyToken", "MTK");
        __ERC20Pausable_init();
        __Ownable_init(initialOwner);
        VRFConsumerBaseV2Plus(0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B);
    }

    ///@notice Set the house fee
    ///@param percentage The percentage value in whole number
    function setFee(percentage) public onlyOwner {
        houseFee = percentage;
    }

    ///@notice Deposit Pre-determined amount
    function deposit(uint256 amount) public whenNotPaused {
        require(
            amount % rafflePrice == 0,
            "You must provide %s per ticket".format(rafflePrice)
        );
        uint256 numberOfTickets = amount / rafflePrice;

        (success) = aliceToken.transferFrom(msg.sender, address(this), amount);
        require(success);
        currentPool += amount;
        for (uint256 i = 0; i < numberOfTickets; i += 1) {
            members.push(msg.sender);
        }
        //prevent double spending
        if (claimedRewards[msg.sender] < raffleID) {
            claimedRewards[msg.sender] = raffleID;
            emit RewardCRC2(msg.sender, genericReward, genericRewardAmount);
        }
    }
    function claimReward() public whenPaused {
        if (winners[raffleID] != msg.sender) {
            revert YouAreNotWinner();
        }
        if (claimedRewards[msg.sender] == raffleID) {
            revert RewardAlreadyClaimed();
        }
        claimedRewards[msg.sender] = raffleID;
        emit RewardCRC2(msg.sender, winnerReward, winnerRewardAmount);
        uint256 memory prize = currentPool;
        currentPool = 0;
        aliceToken.transferFrom(
            address(this),
            msg.sender,
            prize - (prize * houseFee) / 10000
        );
    }
    ///@notice Callback function used by VRF Coordinator
    ///@param requestId The ID of the randomness request
    ///@param randomWords The array of random words generated
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        uint256 winnerIndex = (randomWords[0] % members.length());
        emit WinnerSelected(members[winnerIndex], raffleID);
        winners[members[winnerIndex]] = raffleID;
    }

    ///@notice Start accepting deposits
    ///@param _startTime First block after a specified time which starts raffle
    ///@param _crc2Token The name of the CRC2 Token to reward the winner
    ///@param _amount The amount of the CRC2 Token reward
    function startRaffle(
        uint256 _startTime,
        string _crc2Token,
        uint8 _amount
    ) public onlyOwner whenPaused {
        //Enable raffle feature flag
        _unpause();
        raffleID++;
    }

    ///@notice Stop accepting deposits
    function stopRaffle() public onlyOwner whenNotPaused {
        //Call VRF
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: s_keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
        pause();
    }

    ///@notice update function required by solidity
    ///@param from from
    ///@param to to
    ///@param value value
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20Upgradeable, ERC20PausableUpgradeable) {
        super._update(from, to, value);
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
