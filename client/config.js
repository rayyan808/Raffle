/**
 * Raffle dApp Configuration
 * 
 * Update these values before deploying your dApp
 */

const CONFIG = {
  RAFFLE_CONTRACT_ADDRESS: '0x2688184E2bBde09b7D22f0691f0D4ebbD3b39b1C',
  ACTIVE_NETWORK: 'sepolia',
  ALICE_DECIMALS: 6,
  // Get your client ID from https://dashboard.web3auth.io
  WEB3AUTH_CLIENT_ID: 'BCjQ33Sgyu2Ud25FasdXWMTBWTGyb82RKcuyPPe4HX9v8L_FLPJ9KYkKT-nxAiRhsnyJ8DwQDyV_71-IYs5Wef0',
  
  // Web3Auth network: 'sapphire_devnet' for testing, 'sapphire_mainnet' for production
  WEB3AUTH_NETWORK: 'sapphire_devnet',

  NETWORKS: {
    mainnet: {
      chainId: '0x1',
      chainNamespace: 'eip155',
      rpcTarget: 'https://eth.llamarpc.com',
      displayName: 'Ethereum Mainnet',
      blockExplorer: 'https://etherscan.io',
      ticker: 'ETH',
      tickerName: 'Ethereum',
    },
    sepolia: {
      chainId: '0xaa36a7',
      chainNamespace: 'eip155',
      rpcTarget: 'https://rpc.sepolia.org',
      displayName: 'Sepolia Testnet',
      blockExplorer: 'https://sepolia.etherscan.io',
      ticker: 'ETH',
      tickerName: 'Ethereum',
    },
    bsc: {
      chainId: '0x38',
      chainNamespace: 'eip155',
      rpcTarget: 'https://bsc-dataseed.binance.org',
      displayName: 'BNB Smart Chain',
      blockExplorer: 'https://bscscan.com',
      ticker: 'BNB',
      tickerName: 'BNB',
    },
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
  POLL_INTERVAL: 15000,
  TOAST_DURATION: 4000,
};

if (typeof module !== 'undefined' && module.exports) {
  module.exports = CONFIG;
} else {
  window.RAFFLE_CONFIG = CONFIG;
}
