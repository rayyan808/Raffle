# ALICE Raffle dApp

A sleek, cyberpunk-themed web interface for interacting with the Raffle smart contract. Uses Web3Auth for seamless wallet connection without requiring users to install browser extensions.

![Raffle dApp](https://via.placeholder.com/800x400/0a0a0f/00f0ff?text=ALICE+RAFFLE+dApp)

## Features

- 🔐 **Web3Auth Integration** - Social login & wallet connection
- 🎰 **Two States**:
  - **Active Raffle**: Shows prize pool, ticket count, and rewards
  - **Ended Raffle**: Shows winner, prize, and claim button
- 🏆 **Winner Claiming** - Easy one-click reward claiming
- 📊 **Real-time Updates** - Auto-refreshes every 15 seconds
- 🌙 **Cyberpunk UI** - Distinctive neon-themed design
- 📱 **Responsive** - Works on desktop and mobile

## Quick Start

### 1. Get Web3Auth Client ID

1. Go to [Web3Auth Dashboard](https://dashboard.web3auth.io)
2. Create a new project
3. Copy your **Client ID**

### 2. Configure the dApp

Edit `config.js`:

```javascript
const CONFIG = {
  // Your deployed contract address
  RAFFLE_CONTRACT_ADDRESS: '0x2688184E2bBde09b7D22f0691f0D4ebbD3b39b1C',
  
  // Your Web3Auth client ID
  WEB3AUTH_CLIENT_ID: 'BDDZn304WlG4B8p74tqVwULWjcnUVqHJwXKILEFRaGhk5qLXI6-btQUvN_f2Lf3SOZSWxj5s8XGQOfjLwc-Ktgs',
  
  // Network to use
  ACTIVE_NETWORK: 'sepolia', // or 'mainnet', 'bsc', 'bscTestnet'
};
```

Or edit directly in `index.html`:

```javascript
const RAFFLE_CONTRACT_ADDRESS = '0xYourContractAddress';
const WEB3AUTH_CLIENT_ID = 'YOUR_WEB3AUTH_CLIENT_ID';
```

### 3. Deploy

**Option A: Local Testing**
```bash
# Using Python
python -m http.server 8080

# Using Node.js
npx serve .

# Using PHP
php -S localhost:8080
```

Then open `http://localhost:8080`

**Option B: Static Hosting**

Upload to any static hosting:
- Vercel
- Netlify
- GitHub Pages
- AWS S3
- IPFS

## File Structure

```
raffle-dapp/
├── index.html      # Main dApp (self-contained)
├── config.js       # Configuration file
└── README.md       # This file
```

## Configuration Options

### Networks

| Network | Config Key | Chain ID |
|---------|------------|----------|
| Ethereum Mainnet | `mainnet` | 1 |
| Ethereum Sepolia | `sepolia` | 11155111 |
| BSC Mainnet | `bsc` | 56 |
| BSC Testnet | `bscTestnet` | 97 |

### Web3Auth Network

| Environment | Value |
|-------------|-------|
| Development | `sapphire_devnet` |
| Production | `sapphire_mainnet` |

## User Flow

### When Raffle is Active (State B)

1. User sees:
   - "Raffle Active" status badge
   - Current prize pool in ALICE
   - Number of tickets sold
   - Generic participation reward details
   - Winner reward details

### When Raffle is Ended (State A)

1. User sees:
   - "Raffle Ended" status badge
   - Winner address (or "YOU!" if they won)
   - Prize amount
   - Winner reward details

2. If user is winner and hasn't claimed:
   - "Claim Your Reward" button appears
   - Click to claim prize + NFT reward

## Customization

### Changing Colors

Edit CSS variables in `index.html`:

```css
:root {
  --color-accent-primary: #00f0ff;    /* Cyan glow */
  --color-accent-secondary: #ff00aa;   /* Pink accent */
  --color-accent-gold: #ffd700;        /* Gold/winner color */
  --color-bg-primary: #0a0a0f;         /* Dark background */
}
```

### Changing Fonts

The dApp uses:
- **Orbitron** - Display/headings (futuristic)
- **Rajdhani** - Body text (technical)

Replace the Google Fonts import to change fonts.

## Dependencies

All loaded via CDN (no build step required):

- React 18
- Babel (for JSX)
- ethers.js 5.7
- Web3Auth Modal SDK

## Browser Support

- Chrome/Edge (recommended)
- Firefox
- Safari
- Mobile browsers

## Troubleshooting

### "Failed to load raffle data"

1. Check that `RAFFLE_CONTRACT_ADDRESS` is correct
2. Verify you're on the correct network
3. Ensure the contract is deployed and verified

### Web3Auth not loading

1. Verify `WEB3AUTH_CLIENT_ID` is correct
2. Check Web3Auth dashboard for allowed origins
3. For localhost, add `http://localhost:PORT` to allowed origins

### Transaction failing

1. Check wallet has enough ETH/BNB for gas
2. Verify you're the actual winner
3. Check if prize was already claimed

## Security Notes

- No private keys are stored in the dApp
- All authentication is handled by Web3Auth
- Contract interactions require user signature
- Read operations work without wallet connection

## License

MIT

## Support

For issues with:
- **Smart Contract**: Check contract audit and tests
- **Web3Auth**: Visit [Web3Auth Docs](https://web3auth.io/docs)
- **dApp UI**: Open an issue in this repository
