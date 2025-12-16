import { ethers, Contract, Wallet, Provider, formatUnits, parseUnits, ContractTransactionResponse, ContractTransactionReceipt } from 'ethers';
import * as dotenv from 'dotenv';

dotenv.config();

// ============ Contract ABI ============
// Only includes external/public functions

const RAFFLE_ABI = [
  // Constructor (for reference)
  "constructor(uint256 _subscriptionId, address _aliceToken, address _vrfCoordinator, bytes32 _keyHash, uint32 _callbackGasLimit, uint16 _requestConfirmations, uint256 _houseFee)",

  // ============ State Variables (Public Getters) ============
  "function aliceToken() view returns (address)",
  "function subscriptionId() view returns (uint256)",
  "function keyHash() view returns (bytes32)",
  "function callbackGasLimit() view returns (uint32)",
  "function requestConfirmations() view returns (uint16)",
  "function currentRaffleId() view returns (uint256)",
  "function awaitingVRF() view returns (bool)",
  "function houseFee() view returns (uint256)",
  "function accumulatedHouseFees() view returns (uint256)",
  "function paused() view returns (bool)",
  "function owner() view returns (address)",
  "function raffles(uint256) view returns (uint256 ticketPrice, string genericReward, uint8 genericRewardAmount, string winnerReward, uint8 winnerRewardAmount, uint256 prizePool, address winner, bool winnerClaimed, bool isActive)",
  "function userTicketCount(uint256 raffleId, address user) view returns (uint256)",

  // ============ View Functions ============
  "function getTicketCount(uint256 raffleId) view returns (uint256)",
  "function getRaffleConfig(uint256 raffleId) view returns (tuple(uint256 ticketPrice, string genericReward, uint8 genericRewardAmount, string winnerReward, uint8 winnerRewardAmount, uint256 prizePool, address winner, bool winnerClaimed, bool isActive))",
  "function getWinner(uint256 raffleId) view returns (address)",
  "function getPrizePool(uint256 raffleId) view returns (uint256)",
  "function hasClaimedGeneric(uint256 raffleId, address user) view returns (bool)",
  "function getTicketPriceFormatted(uint256 raffleId) view returns (uint256)",
  "function getUserTickets(uint256 raffleId, address user) view returns (uint256)",
  "function calculateWinnerPrize(uint256 raffleId) view returns (uint256)",

  // ============ User Functions ============
  "function deposit(uint256 amount)",
  "function claimWinnerReward(uint256 raffleId)",
  "function injectCapital(uint256 amount)",

  // ============ Admin Functions ============
  "function startRaffle(uint256 _ticketPrice, string _genericReward, uint8 _genericAmount, string _winnerReward, uint8 _winnerAmount)",
  "function stopRaffle()",
  "function setHouseFee(uint256 _houseFee)",
  "function updateVRFConfig(uint256 _subscriptionId, bytes32 _keyHash, uint32 _callbackGasLimit, uint16 _requestConfirmations)",
  "function withdrawHouseFees(address recipient)",
  "function emergencyPause()",
  "function transferOwnership(address newOwner)",

  // ============ Events ============
  "event Deposit(address indexed user, uint256 indexed raffleId, uint256 amount, uint256 ticketCount)",
  "event GenericRewardClaimed(address indexed wallet, uint256 indexed raffleId, string token, uint8 amount)",
  "event WinnerRewardClaimed(address indexed winner, uint256 indexed raffleId, string token, uint8 tokenAmount, uint256 prizeAmount)",
  "event WinnerSelected(address indexed winner, uint256 indexed raffleId, uint256 winnerIndex)",
  "event RaffleStarted(uint256 indexed raffleId, uint256 ticketPrice)",
  "event RaffleStopped(uint256 indexed raffleId, uint256 requestId, uint256 totalTickets)",
  "event CapitalInjected(address indexed injector, uint256 indexed raffleId, uint256 amount)",
  "event HouseFeesWithdrawn(address indexed recipient, uint256 amount)",
  "event HouseFeeUpdated(uint256 oldFee, uint256 newFee)",
  "event VRFConfigUpdated(uint256 subscriptionId, bytes32 keyHash, uint32 callbackGasLimit, uint16 requestConfirmations)",
  "event Paused(address account)",
  "event Unpaused(address account)",
  "event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)",

  // ============ Errors ============
  "error InvalidAmount()",
  "error InvalidTicketPrice()",
  "error NotWinner()",
  "error RewardAlreadyClaimed()",
  "error RaffleNotActive()",
  "error RaffleStillActive()",
  "error NoParticipants()",
  "error VRFRequestPending()",
  "error InvalidVRFRequest()",
  "error InvalidFee()",
  "error NothingToWithdraw()",
  "error InvalidAddress()",
  "error TransferFailed()",
] as const;

const ERC20_ABI = [
  "function name() view returns (string)",
  "function symbol() view returns (string)",
  "function decimals() view returns (uint8)",
  "function balanceOf(address account) view returns (uint256)",
  "function allowance(address owner, address spender) view returns (uint256)",
  "function approve(address spender, uint256 amount) returns (bool)",
  "function transfer(address to, uint256 amount) returns (bool)",
  "event Approval(address indexed owner, address indexed spender, uint256 value)",
  "event Transfer(address indexed from, address indexed to, uint256 value)",
] as const;

// ============ Types ============

interface RaffleConfig {
  ticketPrice: bigint;
  genericReward: string;
  genericRewardAmount: number;
  winnerReward: string;
  winnerRewardAmount: number;
  prizePool: bigint;
  winner: string;
  winnerClaimed: boolean;
  isActive: boolean;
}

interface NetworkConfig {
  name: string;
  rpcUrl: string;
  chainId: number;
  explorerUrl: string;
}

// ============ Raffle Client Class ============

export class RaffleClient {
  public provider: Provider;
  public signer: Wallet | null = null;
  public raffleContract: Contract;
  public aliceContract: Contract | null = null;
  public network: NetworkConfig;
  public aliceDecimals: number = 6;

  constructor(
    raffleAddress: string,
    network: string | NetworkConfig,
    privateKey?: string
  ) {
    // Setup network
    if (typeof network === 'string') {
      if (!NETWORKS[network]) {
        throw new Error(`Unknown network: ${network}. Available: ${Object.keys(NETWORKS).join(', ')}`);
      }
      this.network = NETWORKS[network];
    } else {
      this.network = network;
    }

    // Setup provider
    this.provider = new ethers.JsonRpcProvider(this.network.rpcUrl);

    // Setup signer if private key provided
    if (privateKey) {
      this.signer = new Wallet(privateKey, this.provider);
    }

    // Setup raffle contract
    this.raffleContract = new Contract(
      raffleAddress,
      RAFFLE_ABI,
      this.signer || this.provider
    );
  }

  // ============ Initialization ============

  /**
   * Initialize the client and fetch ALICE token contract
   */
  async initialize(): Promise<void> {
    const aliceAddress = await this.raffleContract.aliceToken();
    this.aliceContract = new Contract(
      aliceAddress,
      ERC20_ABI,
      this.signer || this.provider
    );
    this.aliceDecimals = await this.aliceContract.decimals();
    
    console.log('RaffleClient initialized');
    console.log(`  Network: ${this.network.name}`);
    console.log(`  Raffle Contract: ${await this.raffleContract.getAddress()}`);
    console.log(`  ALICE Token: ${aliceAddress}`);
    console.log(`  ALICE Decimals: ${this.aliceDecimals}`);
    if (this.signer) {
      console.log(`  Signer: ${await this.signer.getAddress()}`);
    }
  }

  // ============ Helper Functions ============

  /**
   * Parse ALICE amount with proper decimals
   */
  parseAlice(amount: string | number): bigint {
    return parseUnits(amount.toString(), this.aliceDecimals);
  }

  /**
   * Format ALICE amount for display
   */
  formatAlice(amount: bigint): string {
    return formatUnits(amount, this.aliceDecimals);
  }

  /**
   * Format basis points to percentage
   */
  formatBasisPoints(bps: bigint): string {
    return `${Number(bps) / 100}%`;
  }

  /**
   * Get transaction URL on block explorer
   */
  getTxUrl(txHash: string): string {
    if (!this.network.explorerUrl) return txHash;
    return `${this.network.explorerUrl}/tx/${txHash}`;
  }

  /**
   * Wait for transaction and log result
   */
  async waitForTx(tx: ContractTransactionResponse, description: string): Promise<ContractTransactionReceipt> {
    console.log(`\n⏳ ${description}...`);
    console.log(`   Transaction: ${this.getTxUrl(tx.hash)}`);
    
    const receipt = await tx.wait();
    if (!receipt) {
      throw new Error('Transaction failed - no receipt');
    }
    
    console.log(`✅ Confirmed in block ${receipt.blockNumber}`);
    console.log(`   Gas used: ${receipt.gasUsed.toString()}`);
    
    return receipt;
  }

  // ============ Read Functions ============

  /**
   * Get contract info
   */
  async getContractInfo(): Promise<{
    owner: string;
    aliceToken: string;
    currentRaffleId: bigint;
    houseFee: bigint;
    accumulatedHouseFees: bigint;
    paused: boolean;
    awaitingVRF: boolean;
  }> {
    const [owner, aliceToken, currentRaffleId, houseFee, accumulatedHouseFees, paused, awaitingVRF] = 
      await Promise.all([
        this.raffleContract.owner(),
        this.raffleContract.aliceToken(),
        this.raffleContract.currentRaffleId(),
        this.raffleContract.houseFee(),
        this.raffleContract.accumulatedHouseFees(),
        this.raffleContract.paused(),
        this.raffleContract.awaitingVRF(),
      ]);

    return { owner, aliceToken, currentRaffleId, houseFee, accumulatedHouseFees, paused, awaitingVRF };
  }

  /**
   * Get VRF configuration
   */
  async getVRFConfig(): Promise<{
    subscriptionId: bigint;
    keyHash: string;
    callbackGasLimit: number;
    requestConfirmations: number;
  }> {
    const [subscriptionId, keyHash, callbackGasLimit, requestConfirmations] = 
      await Promise.all([
        this.raffleContract.subscriptionId(),
        this.raffleContract.keyHash(),
        this.raffleContract.callbackGasLimit(),
        this.raffleContract.requestConfirmations(),
      ]);

    return { subscriptionId, keyHash, callbackGasLimit, requestConfirmations };
  }

  /**
   * Get raffle configuration by ID
   */
  async getRaffleConfig(raffleId: number): Promise<RaffleConfig> {
    const config = await this.raffleContract.getRaffleConfig(raffleId);
    return {
      ticketPrice: config.ticketPrice,
      genericReward: config.genericReward,
      genericRewardAmount: config.genericRewardAmount,
      winnerReward: config.winnerReward,
      winnerRewardAmount: config.winnerRewardAmount,
      prizePool: config.prizePool,
      winner: config.winner,
      winnerClaimed: config.winnerClaimed,
      isActive: config.isActive,
    };
  }

  /**
   * Get current raffle configuration
   */
  async getCurrentRaffleConfig(): Promise<RaffleConfig & { raffleId: bigint }> {
    const raffleId = await this.raffleContract.currentRaffleId();
    const config = await this.getRaffleConfig(Number(raffleId));
    return { ...config, raffleId };
  }

  /**
   * Get ticket count for a raffle
   */
  async getTicketCount(raffleId: number): Promise<bigint> {
    return this.raffleContract.getTicketCount(raffleId);
  }

  /**
   * Get winner of a raffle
   */
  async getWinner(raffleId: number): Promise<string> {
    return this.raffleContract.getWinner(raffleId);
  }

  /**
   * Get prize pool for a raffle
   */
  async getPrizePool(raffleId: number): Promise<bigint> {
    return this.raffleContract.getPrizePool(raffleId);
  }

  /**
   * Check if user has claimed generic reward
   */
  async hasClaimedGeneric(raffleId: number, user: string): Promise<boolean> {
    return this.raffleContract.hasClaimedGeneric(raffleId, user);
  }

  /**
   * Get ticket price formatted (without decimals)
   */
  async getTicketPriceFormatted(raffleId: number): Promise<bigint> {
    return this.raffleContract.getTicketPriceFormatted(raffleId);
  }

  /**
   * Get user's ticket count for a raffle
   */
  async getUserTickets(raffleId: number, user: string): Promise<bigint> {
    return this.raffleContract.getUserTickets(raffleId, user);
  }

  /**
   * Calculate winner prize after fees
   */
  async calculateWinnerPrize(raffleId: number): Promise<bigint> {
    return this.raffleContract.calculateWinnerPrize(raffleId);
  }

  /**
   * Get ALICE balance for an address
   */
  async getAliceBalance(address: string): Promise<bigint> {
    if (!this.aliceContract) {
      throw new Error('Client not initialized. Call initialize() first.');
    }
    return this.aliceContract.balanceOf(address);
  }

  /**
   * Get ALICE allowance for raffle contract
   */
  async getAllowance(owner: string): Promise<bigint> {
    if (!this.aliceContract) {
      throw new Error('Client not initialized. Call initialize() first.');
    }
    return this.aliceContract.allowance(owner, await this.raffleContract.getAddress());
  }

  // ============ User Write Functions ============

  /**
   * Approve ALICE tokens for deposit
   */
  async approveAlice(amount: bigint): Promise<ContractTransactionReceipt> {
    if (!this.signer || !this.aliceContract) {
      throw new Error('Signer required for write operations');
    }

    const tx = await this.aliceContract.approve(
      await this.raffleContract.getAddress(),
      amount
    );

    return this.waitForTx(tx, `Approving ${this.formatAlice(amount)} ALICE`);
  }

  /**
   * Deposit ALICE to buy raffle tickets
   */
  async deposit(amount: bigint): Promise<ContractTransactionReceipt> {
    if (!this.signer) {
      throw new Error('Signer required for write operations');
    }

    // Check allowance
    const allowance = await this.getAllowance(await this.signer.getAddress());
    if (allowance < amount) {
      console.log('Insufficient allowance, approving...');
      await this.approveAlice(amount);
    }

    const tx = await this.raffleContract.deposit(amount);
    return this.waitForTx(tx, `Depositing ${this.formatAlice(amount)} ALICE`);
  }

  /**
   * Deposit ALICE by specifying number of tickets
   */
  async depositTickets(numberOfTickets: number): Promise<ContractTransactionReceipt> {
    const config = await this.getCurrentRaffleConfig();
    const amount = config.ticketPrice * BigInt(numberOfTickets);
    return this.deposit(amount);
  }

  /**
   * Claim winner reward for a raffle
   */
  async claimWinnerReward(raffleId: number): Promise<ContractTransactionReceipt> {
    if (!this.signer) {
      throw new Error('Signer required for write operations');
    }

    const tx = await this.raffleContract.claimWinnerReward(raffleId);
    return this.waitForTx(tx, `Claiming winner reward for raffle #${raffleId}`);
  }

  /**
   * Inject capital into the current raffle pool
   */
  async injectCapital(amount: bigint): Promise<ContractTransactionReceipt> {
    if (!this.signer) {
      throw new Error('Signer required for write operations');
    }

    // Check allowance
    const allowance = await this.getAllowance(await this.signer.getAddress());
    if (allowance < amount) {
      console.log('Insufficient allowance, approving...');
      await this.approveAlice(amount);
    }

    const tx = await this.raffleContract.injectCapital(amount);
    return this.waitForTx(tx, `Injecting ${this.formatAlice(amount)} ALICE capital`);
  }

  // ============ Admin Write Functions ============

  /**
   * Start a new raffle (owner only)
   */
  async startRaffle(
    ticketPrice: bigint,
    genericReward: string,
    genericAmount: number,
    winnerReward: string,
    winnerAmount: number
  ): Promise<ContractTransactionReceipt> {
    if (!this.signer) {
      throw new Error('Signer required for write operations');
    }

    const tx = await this.raffleContract.startRaffle(
      ticketPrice,
      genericReward,
      genericAmount,
      winnerReward,
      winnerAmount
    );

    return this.waitForTx(tx, 'Starting new raffle');
  }

  /**
   * Stop the current raffle and trigger VRF (owner only)
   */
  async stopRaffle(): Promise<ContractTransactionReceipt> {
    if (!this.signer) {
      throw new Error('Signer required for write operations');
    }

    const tx = await this.raffleContract.stopRaffle();
    return this.waitForTx(tx, 'Stopping raffle and requesting VRF');
  }

  /**
   * Set house fee in basis points (owner only)
   */
  async setHouseFee(feeBps: number): Promise<ContractTransactionReceipt> {
    if (!this.signer) {
      throw new Error('Signer required for write operations');
    }

    if (feeBps > 5000) {
      throw new Error('House fee cannot exceed 50% (5000 bps)');
    }

    const tx = await this.raffleContract.setHouseFee(feeBps);
    return this.waitForTx(tx, `Setting house fee to ${feeBps / 100}%`);
  }

  /**
   * Update VRF configuration (owner only)
   */
  async updateVRFConfig(
    subscriptionId: bigint,
    keyHash: string,
    callbackGasLimit: number,
    requestConfirmations: number
  ): Promise<ContractTransactionReceipt> {
    if (!this.signer) {
      throw new Error('Signer required for write operations');
    }

    const tx = await this.raffleContract.updateVRFConfig(
      subscriptionId,
      keyHash,
      callbackGasLimit,
      requestConfirmations
    );

    return this.waitForTx(tx, 'Updating VRF configuration');
  }

  /**
   * Withdraw accumulated house fees (owner only)
   */
  async withdrawHouseFees(recipient: string): Promise<ContractTransactionReceipt> {
    if (!this.signer) {
      throw new Error('Signer required for write operations');
    }

    const tx = await this.raffleContract.withdrawHouseFees(recipient);
    return this.waitForTx(tx, `Withdrawing house fees to ${recipient}`);
  }

  /**
   * Emergency pause (owner only)
   */
  async emergencyPause(): Promise<ContractTransactionReceipt> {
    if (!this.signer) {
      throw new Error('Signer required for write operations');
    }

    const tx = await this.raffleContract.emergencyPause();
    return this.waitForTx(tx, 'Emergency pausing contract');
  }

  /**
   * Transfer ownership (owner only)
   */
  async transferOwnership(newOwner: string): Promise<ContractTransactionReceipt> {
    if (!this.signer) {
      throw new Error('Signer required for write operations');
    }

    const tx = await this.raffleContract.transferOwnership(newOwner);
    return this.waitForTx(tx, `Transferring ownership to ${newOwner}`);
  }

  // ============ Event Listeners ============

  /**
   * Listen for Deposit events
   */
  onDeposit(callback: (user: string, raffleId: bigint, amount: bigint, ticketCount: bigint) => void): void {
    this.raffleContract.on('Deposit', callback);
  }

  /**
   * Listen for WinnerSelected events
   */
  onWinnerSelected(callback: (winner: string, raffleId: bigint, winnerIndex: bigint) => void): void {
    this.raffleContract.on('WinnerSelected', callback);
  }

  /**
   * Listen for RaffleStarted events
   */
  onRaffleStarted(callback: (raffleId: bigint, ticketPrice: bigint) => void): void {
    this.raffleContract.on('RaffleStarted', callback);
  }

  /**
   * Listen for RaffleStopped events
   */
  onRaffleStopped(callback: (raffleId: bigint, requestId: bigint, totalTickets: bigint) => void): void {
    this.raffleContract.on('RaffleStopped', callback);
  }

  /**
   * Listen for GenericRewardClaimed events
   */
  onGenericRewardClaimed(callback: (wallet: string, raffleId: bigint, token: string, amount: number) => void): void {
    this.raffleContract.on('GenericRewardClaimed', callback);
  }

  /**
   * Listen for WinnerRewardClaimed events
   */
  onWinnerRewardClaimed(callback: (winner: string, raffleId: bigint, token: string, tokenAmount: number, prizeAmount: bigint) => void): void {
    this.raffleContract.on('WinnerRewardClaimed', callback);
  }

  /**
   * Remove all event listeners
   */
  removeAllListeners(): void {
    this.raffleContract.removeAllListeners();
  }

  // ============ Query Historical Events ============

  /**
   * Get past Deposit events
   */
  async getPastDeposits(raffleId?: number, fromBlock?: number): Promise<Array<{
    user: string;
    raffleId: bigint;
    amount: bigint;
    ticketCount: bigint;
    blockNumber: number;
    transactionHash: string;
  }>> {
    const filter = this.raffleContract.filters.Deposit(null, raffleId ?? null);
    const events = await this.raffleContract.queryFilter(filter, fromBlock ?? 0);
    
    return events.map(event => {
      const log = event as ethers.EventLog;
      return {
        user: log.args[0],
        raffleId: log.args[1],
        amount: log.args[2],
        ticketCount: log.args[3],
        blockNumber: log.blockNumber,
        transactionHash: log.transactionHash,
      };
    });
  }

  /**
   * Get past WinnerSelected events
   */
  async getPastWinners(fromBlock?: number): Promise<Array<{
    winner: string;
    raffleId: bigint;
    winnerIndex: bigint;
    blockNumber: number;
    transactionHash: string;
  }>> {
    const filter = this.raffleContract.filters.WinnerSelected();
    const events = await this.raffleContract.queryFilter(filter, fromBlock ?? 0);
    
    return events.map(event => {
      const log = event as ethers.EventLog;
      return {
        winner: log.args[0],
        raffleId: log.args[1],
        winnerIndex: log.args[2],
        blockNumber: log.blockNumber,
        transactionHash: log.transactionHash,
      };
    });
  }
}

// ============ Display Helpers ============

export async function displayContractStatus(client: RaffleClient): Promise<void> {
  console.log('\n' + '='.repeat(60));
  console.log('RAFFLE CONTRACT STATUS');
  console.log('='.repeat(60));

  const info = await client.getContractInfo();
  const vrfConfig = await client.getVRFConfig();

  console.log('\n📋 General Info:');
  console.log(`   Owner: ${info.owner}`);
  console.log(`   ALICE Token: ${info.aliceToken}`);
  console.log(`   Current Raffle ID: ${info.currentRaffleId}`);
  console.log(`   House Fee: ${client.formatBasisPoints(info.houseFee)}`);
  console.log(`   Accumulated Fees: ${client.formatAlice(info.accumulatedHouseFees)} ALICE`);
  console.log(`   Paused: ${info.paused}`);
  console.log(`   Awaiting VRF: ${info.awaitingVRF}`);

  console.log('\n🔗 VRF Configuration:');
  console.log(`   Subscription ID: ${vrfConfig.subscriptionId}`);
  console.log(`   Key Hash: ${vrfConfig.keyHash}`);
  console.log(`   Callback Gas Limit: ${vrfConfig.callbackGasLimit}`);
  console.log(`   Request Confirmations: ${vrfConfig.requestConfirmations}`);

  if (info.currentRaffleId > 0n) {
    const raffleConfig = await client.getCurrentRaffleConfig();
    const ticketCount = await client.getTicketCount(Number(info.currentRaffleId));
    const winnerPrize = await client.calculateWinnerPrize(Number(info.currentRaffleId));

    console.log('\n🎰 Current Raffle:');
    console.log(`   Raffle ID: ${raffleConfig.raffleId}`);
    console.log(`   Active: ${raffleConfig.isActive}`);
    console.log(`   Ticket Price: ${client.formatAlice(raffleConfig.ticketPrice)} ALICE`);
    console.log(`   Total Tickets: ${ticketCount}`);
    console.log(`   Prize Pool: ${client.formatAlice(raffleConfig.prizePool)} ALICE`);
    console.log(`   Winner Prize (after fees): ${client.formatAlice(winnerPrize)} ALICE`);
    console.log(`   Generic Reward: ${raffleConfig.genericReward} x${raffleConfig.genericRewardAmount}`);
    console.log(`   Winner Reward: ${raffleConfig.winnerReward} x${raffleConfig.winnerRewardAmount}`);
    
    if (raffleConfig.winner !== ethers.ZeroAddress) {
      console.log(`   Winner: ${raffleConfig.winner}`);
      console.log(`   Winner Claimed: ${raffleConfig.winnerClaimed}`);
    }
  }

  console.log('\n' + '='.repeat(60));
}

export async function displayUserStatus(client: RaffleClient, userAddress: string): Promise<void> {
  console.log('\n' + '='.repeat(60));
  console.log(`USER STATUS: ${userAddress}`);
  console.log('='.repeat(60));

  const balance = await client.getAliceBalance(userAddress);
  const allowance = await client.getAllowance(userAddress);
  const currentRaffleId = await client.raffleContract.currentRaffleId();

  console.log('\n💰 Token Balances:');
  console.log(`   ALICE Balance: ${client.formatAlice(balance)} ALICE`);
  console.log(`   Approved for Raffle: ${client.formatAlice(allowance)} ALICE`);

  if (currentRaffleId > 0n) {
    const tickets = await client.getUserTickets(Number(currentRaffleId), userAddress);
    const hasClaimed = await client.hasClaimedGeneric(Number(currentRaffleId), userAddress);

    console.log('\n🎟️  Current Raffle Participation:');
    console.log(`   Tickets Owned: ${tickets}`);
    console.log(`   Generic Reward Claimed: ${hasClaimed}`);

    const winner = await client.getWinner(Number(currentRaffleId));
    if (winner.toLowerCase() === userAddress.toLowerCase()) {
      const config = await client.getRaffleConfig(Number(currentRaffleId));
      console.log('\n🏆 YOU ARE THE WINNER!');
      console.log(`   Claimed: ${config.winnerClaimed}`);
      if (!config.winnerClaimed) {
        const prize = await client.calculateWinnerPrize(Number(currentRaffleId));
        console.log(`   Prize Available: ${client.formatAlice(prize)} ALICE`);
      }
    }
  }

  console.log('\n' + '='.repeat(60));
}
// ============ Network Configurations ============

const NETWORKS: Record<string, NetworkConfig> = {
  mainnet: {
    name: 'Ethereum Mainnet',
    rpcUrl: 'https://eth.llamarpc.com',
    chainId: 1,
    explorerUrl: 'https://etherscan.io',
  },
  sepolia: {
    name: 'Ethereum Sepolia',
    rpcUrl: 'https://rpc.sepolia.org',
    chainId: 11155111,
    explorerUrl: 'https://sepolia.etherscan.io',
  },
  bsc: {
    name: 'BSC Mainnet',
    rpcUrl: 'https://bsc-dataseed.binance.org',
    chainId: 56,
    explorerUrl: 'https://bscscan.com',
  },
  bscTestnet: {
    name: 'BSC Testnet',
    rpcUrl: 'https://data-seed-prebsc-1-s1.binance.org:8545',
    chainId: 97,
    explorerUrl: 'https://testnet.bscscan.com',
  },
  localhost: {
    name: 'Localhost',
    rpcUrl: 'http://127.0.0.1:8545',
    chainId: 31337,
    explorerUrl: '',
  },
};

// ============ Example Usage ============

async function main() {
  // Configuration
  /**
   * All of this data should actually come from the config data object and web3 provider
   */
  const RAFFLE_ADDRESS = process.env.RAFFLE_CONTRACT_ADDRESS;
  const PRIVATE_KEY = process.env.PRIVATE_KEY;
  const NETWORK = process.env.NETWORK || 'sepolia';

  if (!RAFFLE_ADDRESS) {
    console.error('❌ RAFFLE_CONTRACT_ADDRESS environment variable not set');
    process.exit(1);
  }

  console.log('🚀 Initializing Raffle Client...\n');

  const client = new RaffleClient(RAFFLE_ADDRESS, NETWORK, PRIVATE_KEY);
  await client.initialize();
  await displayContractStatus(client);

  if (client.signer) {
    const userAddress = await client.signer.getAddress();
    await displayUserStatus(client, userAddress);

    // Example: Listen for events
    console.log('\n👂 Listening for events...');
    
    client.onDeposit((user, raffleId, amount, ticketCount) => {
      console.log(`\n📥 Deposit: ${user} deposited ${client.formatAlice(amount)} ALICE for ${ticketCount} tickets in raffle #${raffleId}`);
    });

    client.onWinnerSelected((winner, raffleId, winnerIndex) => {
      console.log(`\n🏆 Winner Selected: ${winner} won raffle #${raffleId} (index: ${winnerIndex})`);
    });

    client.onRaffleStarted((raffleId, ticketPrice) => {
      console.log(`\n🎰 Raffle Started: #${raffleId} with ticket price ${client.formatAlice(ticketPrice)} ALICE`);
    });

    console.log('Press Ctrl+C to exit\n');
  }
}


main().catch(console.error);