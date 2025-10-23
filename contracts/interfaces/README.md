# TradeSukuk Smart Contract Interfaces

This directory contains the core smart contract interfaces for the TradeSukuk platform - a Shariah-compliant tokenized invoice financing system.

## Overview

TradeSukuk enables the tokenization of Murabaha invoices into ERC-3643 compliant security tokens, allowing fractional ownership and secondary trading while maintaining Islamic finance principles and regulatory compliance.

## Interface Files

### Core Token Standard

**IERC3643.sol**
- Extends ERC-20 with security token features
- Identity registry integration
- Compliance module integration
- Transfer restrictions
- Token freezing mechanisms
- Forced transfers for regulatory compliance
- Batch operations for efficiency

### Security Token

**ITradeSukukToken.sol**
- Full ERC-3643 implementation
- Shariah compliance certification tracking
- Automated profit distribution to token holders
- Token holder management and queries
- Underlying asset linkage
- Redemption mechanisms
- Pause/unpause functionality
- Comprehensive metadata management

Key features:
- Shariah certificate with scholar verification
- Pro-rata profit distribution
- Token holder information tracking
- Asset valuation updates
- Emergency pause controls
- Redemption at maturity or early exit

### Invoice Tokenization

**IMurabahaInvoice.sol**
- Murabaha contract lifecycle management
- Invoice creation and verification
- Tokenization of invoices
- Funding tracking
- Payment receipt and settlement
- Default handling
- Profit calculation

Invoice lifecycle:
1. DRAFT → VERIFIED → TOKENIZED → FUNDED → ACTIVE → PAID → SETTLED

Features:
- Cost-plus pricing (Murabaha model)
- Buyer/seller verification
- Document management (IPFS)
- Shariah compliance checks
- Grace period handling
- Redemption options

### Compliance & Verification

**IComplianceModule.sol**
- KYC/AML verification
- Polygon ID integration for decentralized identity
- Accreditation status management
- Jurisdiction restrictions
- Address blocking/sanctioning
- Transfer compliance validation
- Shariah compliance certification

Compliance checks:
- Identity verification levels
- Accreditation requirements
- Geographic restrictions
- Address blocking
- Transfer restrictions
- Shariah validation

### Secondary Marketplace

**ISecondaryMarketplace.sol**
- Order book management
- Multiple order types (market, limit, stop)
- Order matching engine
- Fee calculation and collection
- Trade execution with compliance checks
- Market statistics and analytics
- Price discovery mechanisms

Trading features:
- Buy/sell orders
- Partial fills
- Order modification
- Batch operations
- Real-time market stats
- Fee structures (maker/taker)
- Trading pause controls

### Profit Distribution

**IProfitDistributor.sol**
- Payment receipt tracking
- Distribution scheduling
- Pro-rata calculation
- Automated profit distribution
- Claim management
- Token redemption
- Maturity handling

Distribution workflow:
1. Receive payment
2. Calculate pro-rata shares
3. Schedule distribution
4. Execute distribution
5. Allow holder claims
6. Handle redemptions

### Common Types

**ICommonTypes.sol**
- Shared data structures
- Common enums (Currency, AssetClass, RiskRating)
- Utility functions
- Constants
- Time calculations
- Validation helpers

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    TradeSukuk Platform                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────────────┐         ┌──────────────────┐           │
│  │ Murabaha       │────────▶│  TradeSukuk      │           │
│  │ Invoice        │         │  Token (ERC3643) │           │
│  └────────────────┘         └──────────────────┘           │
│         │                            │                      │
│         │                            │                      │
│         ▼                            ▼                      │
│  ┌────────────────┐         ┌──────────────────┐           │
│  │  Compliance    │◀────────│   Secondary      │           │
│  │  Module        │         │   Marketplace    │           │
│  └────────────────┘         └──────────────────┘           │
│         │                            │                      │
│         │                            │                      │
│         └────────────┬───────────────┘                      │
│                      ▼                                      │
│              ┌──────────────────┐                           │
│              │  Profit          │                           │
│              │  Distributor     │                           │
│              └──────────────────┘                           │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Key Concepts

### Murabaha (Cost-Plus Financing)
- Seller reveals cost basis
- Profit margin agreed upfront
- Total = Cost Basis + Profit
- Shariah-compliant structure

### ERC-3643 Security Token Standard
- Permissioned transfers
- Identity verification required
- Compliance rules enforced
- Regulatory reporting

### Tokenization Flow
1. Invoice created by seller
2. Compliance verification (KYC/AML/Shariah)
3. Invoice tokenized into security tokens
4. Investors purchase tokens (fractional ownership)
5. Funds transferred to seller
6. Buyer pays invoice at maturity
7. Profit distributed to token holders
8. Tokens redeemed or traded

### Compliance Layers
- **Identity**: KYC/AML verification via Polygon ID
- **Accreditation**: Investor qualification checks
- **Jurisdiction**: Geographic restrictions
- **Shariah**: Islamic finance compliance
- **Transfer Rules**: Token-specific restrictions

## Usage Examples

### Creating an Invoice Token

```solidity
// 1. Create invoice
uint256 invoiceId = murabahaInvoice.createInvoice(
    "INV-12345",
    buyerAddress,
    InvoiceType.TRADE_INVOICE,
    100000, // cost basis
    500,    // 5% profit margin
    maturityDate,
    gracePeriod,
    documentHash
);

// 2. Verify compliance
complianceModule.verifyKYC(seller, VerificationLevel.STANDARD, ...);
complianceModule.verifyKYC(buyer, VerificationLevel.STANDARD, ...);
murabahaInvoice.verifyInvoice(invoiceId, tradeDocsHash, true);

// 3. Tokenize
address tokenAddress = murabahaInvoice.tokenizeInvoice(
    invoiceId,
    1000,    // 1000 tokens
    105,     // $105 per token
    100,     // min investment
    10000,   // max investment
    fundingDeadline
);

// 4. Investors purchase tokens through marketplace
// 5. Invoice funded and activated
// 6. Buyer pays at maturity
// 7. Profit distributed automatically
```

### Trading on Secondary Market

```solidity
// Create sell order
uint256 orderId = marketplace.createOrder(
    tokenAddress,
    OrderSide.SELL,
    OrderType.LIMIT,
    100,  // 100 tokens
    110,  // $110 per token
    0,    // no expiry
    0     // not a stop order
);

// Create buy order (will match if price compatible)
marketplace.createOrder(
    tokenAddress,
    OrderSide.BUY,
    OrderType.MARKET,
    100,
    0,  // market price
    0,
    0
);

// Orders automatically matched if compliant
```

### Claiming Profits

```solidity
// Check claimable amount
uint256 claimable = profitDistributor.getTotalClaimable(tokenAddress, holder);

// Claim all available profits
uint256[] memory distributionIds = getMyDistributions();
profitDistributor.batchClaimProfit(distributionIds);
```

## Integration Points

### External Systems
- **Polygon ID**: Decentralized identity verification
- **IPFS**: Document storage and retrieval
- **Oracles**: Price feeds and market data
- **Payment Rails**: Fiat on/off ramps

### Internal Contracts
- Token contracts implement ITradeSukukToken
- Invoice management implements IMurabahaInvoice
- Compliance engine implements IComplianceModule
- Trading platform implements ISecondaryMarketplace
- Distribution engine implements IProfitDistributor

## Security Considerations

1. **Access Control**: Role-based permissions using OpenZeppelin
2. **Reentrancy Protection**: Non-reentrant modifiers on critical functions
3. **Integer Overflow**: Solidity 0.8+ built-in protection
4. **Front-Running**: Order matching with time-priority
5. **Compliance Bypass**: Multi-layer verification
6. **Emergency Controls**: Pause mechanisms for critical functions

## Development Guidelines

### Interface Design Principles
- Comprehensive NatSpec documentation
- Clear parameter naming
- Explicit return values
- Event emission for state changes
- View functions for queries
- Pure functions for calculations

### Best Practices
- Use structs for complex data
- Emit events for all state changes
- Include batch operations where applicable
- Provide both immediate and scheduled operations
- Support pagination for large result sets
- Include metadata and documentation references

## Testing Requirements

Each interface should have:
- Unit tests for all functions
- Integration tests for workflows
- Compliance validation tests
- Edge case handling
- Gas optimization tests
- Security audit preparation

## Version

- Solidity Version: ^0.8.20
- OpenZeppelin Contracts: Latest stable
- ERC-3643 Standard: T-REX Protocol compatible

## License

MIT License

## Contact

- Security Issues: security@tradesukuk.com
- Technical Support: dev@tradesukuk.com
- Documentation: https://docs.tradesukuk.com

## References

- [ERC-3643 Standard](https://eips.ethereum.org/EIPS/eip-3643)
- [T-REX Protocol](https://github.com/TokenySolutions/T-REX)
- [Polygon ID](https://polygon.technology/polygon-id)
- [Islamic Finance Principles](https://www.investopedia.com/terms/i/islamicbanking.asp)
- [Murabaha Contracts](https://www.investopedia.com/terms/m/murabaha.asp)
