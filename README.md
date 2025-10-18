# Reflexus Protocol UTR Token

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.30-blue.svg)](https://soliditylang.org/)
[![BSC](https://img.shields.io/badge/BSC-Compatible-green.svg)](https://bscscan.com/)
[![OpenZeppelin](https://img.shields.io/badge/OpenZeppelin-4.9.3-purple.svg)](https://openzeppelin.com/)

## 🚀 Revolutionary Web3 Token with Mathematically Guaranteed Price Growth

REFLEXUS Protocol presents UTR, a BSC-compliant token that merges native currency backing with fair dividend payments and direct, on-chain refund capabilities. Each UTR token draws value from the contract's accumulated reserves, while transaction fees enable proportional dividend distribution to holders through a fair percentage system.

### ✨ Key Innovations

- **Mathematically Guaranteed Price Growth**: Continuous upward price pressure through innovative refund mechanism
- **99.9% Liquidity Backing**: Always maintain near-perfect liquidity against full market circulation
- **Direct Blockchain Interaction**: Buy, refund, and claim dividends directly through BSCScan or any BSC wallet
- **Self-Reinforcing Economic Design**: Every transaction strengthens the protocol and benefits all holders
- **Zero Third-Party Dependencies**: Complete decentralization with no external service requirements

## 🎯 Core Features

### Native Currency Backing
- Every UTR token is backed by BNB reserves accumulated in the contract
- Users can redeem tokens for native currency at solid, ever-growing backing value
- Ensures liquidity without market dependency

### Revolutionary Refund Mechanism
- **Users will always buy UTRs back at higher price after refunding**
- Creates one-way upward price pressure that benefits all holders
- Refund process: Send UTR tokens to contract → Receive BNB back
- Price automatically increases due to reduced circulating supply

### Continuous Price Growth with 99.9% Liquidity
- **Buy Price**: Refund price × 1.001 (0.1% premium)
- **Refund Price**: (BNB reserves × 99.9%) ÷ circulating supply
- As BNB accumulates and circulating supply decreases, both prices rise
- Always maintains 99.9% backing against circulating supply

### Fair Dividend Distribution
- Transaction fees enable proportional dividend distribution to holders
- 5-10 basis points per transaction distributed as claimable dividends
- Magnified dividend per share ensures precise distribution
- User-controlled claiming with no protocol fees

### Decentralized Web3 Architecture
- **Direct BSCScan Integration**: Buy, refund, claim dividends directly
- **Universal Wallet Support**: Works with 300+ existing BSC-compatible Web3 wallets
- **Simple Operations**: 
  - Buy: Send BNB to UTR contract address `0x649e91d212CcA1e21D4f991a2580f175b95924EB` → receive UTR tokens
  - Refund: Send UTR tokens to UTR contract address `0x649e91d212CcA1e21D4f991a2580f175b95924EB` → receive BNB
  - Claim Dividends: Call `claimDividends()` function directly

## 📊 Tokenomics

### Token Metrics
- **Total Supply**: 1,250,000,000 UTR (Fixed supply with no minting capability)
- **Burn Limit**: 250,000,000 UTR (20% of total supply)
- **Base Price**: 0.0001 BNB/UTR (Starting price with dynamic adjustment)
- **Interest Share**: 0.05% - 0.10% per interaction distributed proportionally

### Fee Structure (25 BPS Total)
| Transaction Type | Dev Fee | Interest Fee | Reserve Fee | Burn Fee | Total |
|------------------|---------|--------------|-------------|----------|-------|
| Buy              | 5 BPS   | 10 BPS       | 10 BPS      | -        | 25 BPS|
| Transfer         | 5 BPS   | 10 BPS       | 10 BPS      | -        | 25 BPS|
| Refund           | 5 BPS   | 5 BPS        | 7.5-15 BPS  | 7.5-0 BPS| 25 BPS|
| DEX Swap         | 5 BPS   | 10 BPS       | 10 BPS      | -        | 25 BPS|

*Refund fees adjust based on burning status: 7.5 BPS burn + 7.5 BPS reserve (under limit) or 0 BPS burn + 15 BPS reserve (over limit)*

## 🔧 Technical Implementation

### Smart Contract Details
- **Solidity Version**: 0.8.30
- **OpenZeppelin**: ERC20, ERC20Permit, Ownable2Step, ReentrancyGuard
- **Security**: Built-in reentrancy protection and overflow safeguards
- **Ownership**: Post-deployment renouncement for true decentralization

### Key Constants
```solidity
uint256 private constant EFFECTIVE_BACKING_NUMERATOR = 999;
uint256 private constant EFFECTIVE_BACKING_DENOMINATOR = 1000;
uint256 private constant MAGNITUDE = 2**128;
uint256 private constant PRECISION_DIVISOR = 10000;
```

### Core Functions
- `buy()`: Purchase UTR tokens by sending BNB to contract
- `claimDividends()`: Claim accumulated dividend rewards
- `pendingDividends(address)`: Check pending dividend amount
- `calculateUtrForNative(uint256)`: Calculate tokens for given BNB amount
- `refund()`: Refund UTR tokens by transferring them to contract address

## 🛡️ Security Features

### Economic Protection Mechanisms
1. **Fee-Based Dividend Generation**: Dividends generated exclusively from transaction fees
2. **Proportional Refund System**: Maintains price stability regardless of reserve changes
3. **Effective Backing Buffer**: 99.9% effective backing with 0.1% accumulating buffer
4. **Self-Regulating Design**: Attack attempts generate more fees for legitimate users

### Built-in Protections
- **Reentrancy Protection**: All external calls protected by ReentrancyGuard
- **Ownership Renouncement**: Eliminates centralized control post-deployment
- **Liquidity Pair Detection**: Automatic exclusion from dividend distributions
- **Fee Validation**: Precise mathematical operations with overflow protection

## 📈 Economic Benefits

### For Users
- **Guaranteed Price Growth**: Mathematical design ensures continuous appreciation
- **High Liquidity**: 99.9% backing ensures liquidity without market dependency
- **Dividend Rewards**: Proportional distribution from all transaction activity
- **Decentralized Access**: Direct blockchain interaction without intermediaries

### For the Protocol
- **Self-Reinforcing**: Every transaction strengthens the system
- **Sustainable Growth**: Fee structure designed for long-term viability
- **Economic Security**: Natural protection against manipulation attempts
- **Community Driven**: Benefits all participants through economic incentives

## 🔄 How It Works

### Price Growth Cycle
1. User buys UTR tokens → BNB added to contract reserves
2. Circulating supply decreases → Refund price increases
3. Next buy price = Refund price × 1.001 (0.1% premium)
4. Cycle repeats → Continuous upward price pressure

### Dividend Distribution
1. Transaction fees accumulate in dividend pool
2. Dividends distributed proportionally based on token holdings
3. Users claim dividends manually via `claimDividends()` function
4. All distributed dividends are fully backed UTR tokens

### Refund Process
1. User transfers UTR tokens to contract address
2. Contract calculates refund value at 99.9% of backing
3. Fees applied: dev (5 BPS), dividend (5 BPS), burn/reserve (15 BPS)
4. BNB transferred to user at calculated rate

## 🌐 Decentralization & Accessibility

### No Third-Party Dependencies
- **No Exchanges Required**: Direct contract interaction via BSCScan
- **No Service Providers**: Protocol operates entirely on blockchain
- **No Censorship**: Anyone can interact without permission
- **24/7 Availability**: Always accessible through blockchain

### Universal Compatibility
- **300+ Wallet Support**: Works with any BSC-compatible Web3 wallet
- **BSCScan Integration**: Full functionality available through block explorer
- **DEX Compatibility**: Optimized for PancakeSwap V2 integration
- **Cross-Platform**: Accessible from any device with Web3 capabilities

## 📚 Documentation

- **[5-AI Audit Report](./5-AI Audit/AIauditResult.md)**: Comprehensive security audit
- **[Vulnerability Audit Report](./VulnerabilityAudit.md)**: Comprehensive security analysis
- **[Economic Protection Mechanisms](./EconomicProtectionMechanisms.md)**: Detailed economic design explanation
- **[White Paper](./whitepaper.md)**: Complete technical and economic documentation

## 🚀 Getting Started

### Prerequisites
- BSC-compatible wallet (MetaMask, Trust Wallet, etc.)
- BNB for gas fees and token purchases

### Quick Start
1. **Connect Wallet**: Connect your BSC-compatible wallet
2. **Buy UTR**: Send BNB directly to contract address `0x649e91d212CcA1e21D4f991a2580f175b95924EB` or use `buy()` function to receive UTR
3. **Claim Dividends**: Call `claimDividends()` to claim accumulated rewards
4. **Refund**: Transfer UTR tokens to contract address `0x649e91d212CcA1e21D4f991a2580f175b95924EB` to receive BNB back

### Contract Address
**0x649e91d212CcA1e21D4f991a2580f175b95924EB**

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

REFLEXUS Protocol uses BNB (Binance Coin) as its backing asset but is **NOT** affiliated with, endorsed by, sponsored by, or in partnership with Binance, Binance Smart Chain, or any Binance-related entities. UTR tokens are an independent project with no official connection to Binance. The use of BNB as backing is purely technical and does not imply any business relationship or endorsement.

## 🔗 Links

- **Website**: [Reflexus Protocol](https://reflexusprotocol.com)
- **WhitePaper**: [Reflexus Protocol](https://reflexus.net/whitepaper)
- **BSCScan**: [BSCScan](https://bscscan.com/token/0x649e91d212CcA1e21D4f991a2580f175b95924EB)


---

**Reflexus Protocol UTR Token** - *The future of tokenomics is here*

*Revolutionary Web3 token with mathematically guaranteed price growth and 99.9% liquidity backing*

