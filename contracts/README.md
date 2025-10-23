# TradeSukuk Smart Contracts

ERC-3643 compliant smart contracts for Shariah-compliant trade finance tokenization on Polygon.

## Overview

TradeSukuk enables the tokenization of Murabaha (cost-plus financing) trade invoices as security tokens, allowing for fractional ownership and secondary market trading while maintaining full Shariah compliance.

## Contracts

### Core Contracts

1. **TradeSukukToken.sol**
   - ERC-3643 compliant security token
   - Represents fractional ownership in trade invoices
   - Integrated compliance and KYC enforcement
   - UUPS upgradeable pattern

2. **MurabahaInvoiceFactory.sol**
   - Factory for creating invoice tokens
   - Manages token lifecycle
   - Tracks asset details and maturity

3. **ComplianceModule.sol**
   - Enforces Shariah compliance rules
   - KYC/AML verification
   - Transfer restrictions
   - Investor limits

4. **SecondaryMarketplace.sol**
   - Order book for token trading
   - Shariah-compliant immediate settlement
   - Maker-taker fee structure
   - Multiple payment token support

5. **ProfitDistributor.sol**
   - Automated profit distribution
   - Snapshot-based claims
   - Proportional allocation
   - Vesting support

### Interfaces

- **IComplianceModule.sol** - ERC-3643 compliance interface
- **IIdentityRegistry.sol** - On-chain identity verification

### Mocks

- **MockIdentityRegistry.sol** - Testing identity registry

## Features

### Shariah Compliance

✅ Asset-backed tokens only
✅ No interest (riba) - profit from trade markup
✅ Immediate settlement (no futures/derivatives)
✅ Transparent pricing and asset backing
✅ Proportional profit distribution

### Security Features

- Role-based access control (RBAC)
- Emergency pause mechanisms
- Wallet freezing capabilities
- Forced transfer for compliance
- UUPS upgradeable proxies
- Reentrancy guards

### Regulatory Compliance

- ERC-3643 security token standard
- On-chain KYC/AML with Polygon ID
- Transfer restrictions
- Country restrictions
- Investor limits
- Audit trail

## Installation

```bash
npm install
```

## Configuration

Create `.env` file from `.env.example`:

```bash
cp .env.example .env
```

Configure:
- `POLYGON_AMOY_RPC_URL` - Polygon Amoy testnet RPC
- `POLYGON_RPC_URL` - Polygon mainnet RPC
- `PRIVATE_KEY` - Deployer private key
- `POLYGONSCAN_API_KEY` - For contract verification

## Compilation

```bash
npm run compile
```

## Testing

```bash
# Run all tests
npm test

# With coverage
npm run coverage

# With gas reporting
REPORT_GAS=true npm test
```

## Deployment

### Polygon Amoy Testnet

```bash
npm run deploy:amoy
```

### Polygon Mainnet

```bash
npm run deploy:polygon
```

### Using Hardhat Ignition

```bash
npx hardhat ignition deploy ./ignition/modules/TradeSukuk.js --network polygonAmoy
```

## Verification

```bash
npm run verify -- --network polygonAmoy <CONTRACT_ADDRESS>
```

## Usage Examples

### Creating an Invoice Token

```typescript
const factory = await ethers.getContractAt("MurabahaInvoiceFactory", FACTORY_ADDRESS);

const maturityDate = Math.floor(Date.now() / 1000) + 365 * 24 * 60 * 60; // 1 year

await factory.createInvoiceToken(
  "INV-001",                           // Invoice ID
  "Murabaha Invoice Token 001",        // Token name
  "MIT001",                             // Token symbol
  ethers.parseEther("100000"),          // Asset value
  500,                                  // Profit margin (5%)
  maturityDate,                         // Maturity date
  "Electronics trade finance",          // Description
  ethers.parseEther("10000")            // Initial supply to mint
);
```

### Trading on Secondary Market

```typescript
const marketplace = await ethers.getContractAt("SecondaryMarketplace", MARKETPLACE_ADDRESS);

// Create sell order
await sukukToken.approve(marketplace.address, amount);
await marketplace.createOrder(
  sukukToken.address,
  usdcToken.address,
  1, // SELL
  ethers.parseEther("1.05"), // Price per token
  ethers.parseEther("1000"),  // Amount
  0 // No expiry
);

// Fill order
await usdcToken.approve(marketplace.address, paymentAmount);
await marketplace.fillOrder(orderId, amount);
```

### Distributing Profits

```typescript
const distributor = await ethers.getContractAt("ProfitDistributor", DISTRIBUTOR_ADDRESS);

// Create distribution
await usdcToken.approve(distributor.address, totalProfitAmount);
await distributor.createDistribution(
  sukukToken.address,
  usdcToken.address,
  totalProfitAmount,
  0, // Current block snapshot
  0, // Immediate claim
  futureTimestamp // Claim deadline
);

// Investors claim
await distributor.claimProfit(distributionId);
```

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   TradeSukuk Platform                    │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────────┐      ┌──────────────────┐        │
│  │ Invoice Factory  │──────│ Sukuk Token      │        │
│  │ (Create Tokens)  │      │ (ERC-3643)       │        │
│  └──────────────────┘      └──────────────────┘        │
│           │                          │                   │
│           │                          │                   │
│  ┌────────▼────────────────────────▼─────────┐         │
│  │      Compliance Module                     │         │
│  │  - Shariah Rules                           │         │
│  │  - KYC/AML Verification                    │         │
│  │  - Transfer Restrictions                   │         │
│  └────────────────────────────────────────────┘         │
│           │                          │                   │
│           │                          │                   │
│  ┌────────▼──────────┐      ┌───────▼──────────┐       │
│  │  Marketplace       │      │ Profit Distrib.  │       │
│  │  (Order Book)      │      │ (Yield Payments) │       │
│  └────────────────────┘      └──────────────────┘       │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

## Security Considerations

1. **Upgradeable Contracts**: Use UUPS pattern with proper access controls
2. **Role Management**: Carefully manage admin/operator roles
3. **Testing**: Comprehensive test coverage before deployment
4. **Audits**: Professional security audit recommended
5. **Polygon ID**: Production integration for real KYC/AML
6. **Emergency Procedures**: Test pause and recovery mechanisms

## Gas Optimization

- Batch operations where possible
- Use `calldata` for external functions
- Optimize storage layout
- Consider layer 2 solutions (Polygon)

## Roadmap

- [ ] Polygon ID integration for production KYC
- [ ] Chainlink price feeds for oracle data
- [ ] Cross-chain bridge support
- [ ] Mobile SDK integration
- [ ] Governance module
- [ ] Staking mechanisms

## License

MIT

## Support

For issues and questions:
- GitHub Issues: [Repository Issues](https://github.com/yourusername/tradesukuk/issues)
- Documentation: [Full Documentation](https://docs.tradesukuk.io)

## Audit Status

⚠️ **NOT AUDITED** - These contracts have not undergone professional security audit. Use at your own risk.
