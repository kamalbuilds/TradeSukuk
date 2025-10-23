const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("TradeSukukDeployment", (m) => {
  // Deploy parameters
  const admin = m.getAccount(0);

  // 1. Deploy MockIdentityRegistry for testing (replace with real Polygon ID integration in production)
  const identityRegistry = m.contract("MockIdentityRegistry", [admin]);

  // 2. Deploy ComplianceModule
  const complianceModule = m.contract("ComplianceModule");

  // Initialize ComplianceModule
  m.call(complianceModule, "initialize", [
    true,                    // shariahComplianceEnabled
    1000000n * 10n ** 18n,  // globalMaxHolding (1M tokens)
    1000n * 10n ** 18n,     // globalMinInvestment (1K tokens)
    admin
  ]);

  // 3. Deploy TradeSukukToken implementation
  const tokenImplementation = m.contract("TradeSukukToken");

  // 4. Deploy MurabahaInvoiceFactory
  const invoiceFactory = m.contract("MurabahaInvoiceFactory");

  // Initialize InvoiceFactory
  m.call(invoiceFactory, "initialize", [
    tokenImplementation,
    complianceModule,
    identityRegistry,
    admin
  ]);

  // 5. Deploy SecondaryMarketplace
  const marketplace = m.contract("SecondaryMarketplace");

  // Initialize Marketplace
  m.call(marketplace, "initialize", [
    25n,   // makerFeeBps (0.25%)
    50n,   // takerFeeBps (0.50%)
    admin, // feeRecipient
    admin
  ]);

  // 6. Deploy ProfitDistributor
  const profitDistributor = m.contract("ProfitDistributor");

  // Initialize ProfitDistributor
  m.call(profitDistributor, "initialize", [admin]);

  return {
    identityRegistry,
    complianceModule,
    tokenImplementation,
    invoiceFactory,
    marketplace,
    profitDistributor
  };
});
