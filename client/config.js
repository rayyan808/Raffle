/**
 * Raffle dApp Configuration
 * 
 * Update these values before deploying your dApp
 */

const CONFIG = {
  // ============ Contract Configuration ============
  
  // Your deployed Raffle contract address
  RAFFLE_CONTRACT_ADDRESS: '0x0000000000000000000000000000000000000000',
  
  // ALICE Token decimals
  ALICE_DECIMALS: 6,

  // ============ Web3Auth Configuration ============
  
  // Get your client ID from https://dashboard.web3auth.io
  WEB3AUTH_CLIENT_ID: 'YOUR_WEB3AUTH_CLIENT_ID',
  
  // Web3Auth network: 'sapphire_devnet' for testing, 'sapphire_mainnet' for production
  WEB3AUTH_NETWORK: 'sapphire_devnet',

  // ============ Network Configuration ============
  
  // Supported networks configuration
  NETWORKS: {
    // Ethereum Mainnet
    mainnet: {
      chainId: '0x1',
      chainNamespace: 'eip155',
      rpcTarget: 'https://eth.llamarpc.com',
      displayName: 'Ethereum Mainnet',
      blockExplorer: 'https://etherscan.io',
      ticker: 'ETH',
      tickerName: 'Ethereum',
    },
    
    // Ethereum Sepolia Testnet
    sepolia: {
      chainId: '0xaa36a7',
      chainNamespace: 'eip155',
      rpcTarget: 'https://rpc.sepolia.org',
      displayName: 'Sepolia Testnet',
      blockExplorer: 'https://sepolia.etherscan.io',
      ticker: 'ETH',
      tickerName: 'Ethereum',
    },
    
    // BSC Mainnet
    bsc: {
      chainId: '0x38',
      chainNamespace: 'eip155',
      rpcTarget: 'https://bsc-dataseed.binance.org',
      displayName: 'BNB Smart Chain',
      blockExplorer: 'https://bscscan.com',
      ticker: 'BNB',
      tickerName: 'BNB',
    },
    
    // BSC Testnet
    bscTestnet: {
      chainId: '0x61',
      chainNamespace: 'eip155',
      rpcTarget: 'https://data-seed-prebsc-1-s1.binance.org:8545',
      displayName: 'BSC Testnet',
      blockExplorer: 'https://testnet.bscscan.com',
      ticker: 'tBNB',
      tickerName: 'Test BNB',
    },
  },
  
  // Active network - change this to switch networks
  ACTIVE_NETWORK: 'sepolia',

  // ============ UI Configuration ============
  
  // Polling interval for contract data (milliseconds)
  POLL_INTERVAL: 15000,
  
  // Toast notification duration (milliseconds)
  TOAST_DURATION: 4000,
};

// Export for use in dApp
if (typeof module !== 'undefined' && module.exports) {
  module.exports = CONFIG;
} else {
  window.RAFFLE_CONFIG = CONFIG;
}
