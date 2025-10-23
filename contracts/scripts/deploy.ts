import { ethers, upgrades } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with account:", deployer.address);
  console.log("Account balance:", (await ethers.provider.getBalance(deployer.address)).toString());

  // 1. Deploy MockIdentityRegistry
  console.log("\n1. Deploying MockIdentityRegistry...");
  const MockIdentityRegistry = await ethers.getContractFactory("MockIdentityRegistry");
  const identityRegistry = await MockIdentityRegistry.deploy(deployer.address);
  await identityRegistry.waitForDeployment();
  console.log("MockIdentityRegistry deployed to:", await identityRegistry.getAddress());

  // 2. Deploy ComplianceModule
  console.log("\n2. Deploying ComplianceModule...");
  const ComplianceModule = await ethers.getContractFactory("ComplianceModule");
  const complianceModule = await upgrades.deployProxy(
    ComplianceModule,
    [
      true,                                      // shariahComplianceEnabled
      ethers.parseEther("1000000"),             // globalMaxHolding (1M tokens)
      ethers.parseEther("1000"),                // globalMinInvestment (1K tokens)
      deployer.address                          // admin
    ],
    { kind: "uups" }
  );
  await complianceModule.waitForDeployment();
  console.log("ComplianceModule deployed to:", await complianceModule.getAddress());

  // 3. Deploy TradeSukukToken implementation
  console.log("\n3. Deploying TradeSukukToken implementation...");
  const TradeSukukToken = await ethers.getContractFactory("TradeSukukToken");
  const tokenImplementation = await TradeSukukToken.deploy();
  await tokenImplementation.waitForDeployment();
  console.log("TradeSukukToken implementation deployed to:", await tokenImplementation.getAddress());

  // 4. Deploy MurabahaInvoiceFactory
  console.log("\n4. Deploying MurabahaInvoiceFactory...");
  const MurabahaInvoiceFactory = await ethers.getContractFactory("MurabahaInvoiceFactory");
  const invoiceFactory = await upgrades.deployProxy(
    MurabahaInvoiceFactory,
    [
      await tokenImplementation.getAddress(),
      await complianceModule.getAddress(),
      await identityRegistry.getAddress(),
      deployer.address
    ],
    { kind: "uups" }
  );
  await invoiceFactory.waitForDeployment();
  console.log("MurabahaInvoiceFactory deployed to:", await invoiceFactory.getAddress());

  // 5. Deploy SecondaryMarketplace
  console.log("\n5. Deploying SecondaryMarketplace...");
  const SecondaryMarketplace = await ethers.getContractFactory("SecondaryMarketplace");
  const marketplace = await upgrades.deployProxy(
    SecondaryMarketplace,
    [
      25,               // makerFeeBps (0.25%)
      50,               // takerFeeBps (0.50%)
      deployer.address, // feeRecipient
      deployer.address  // admin
    ],
    { kind: "uups" }
  );
  await marketplace.waitForDeployment();
  console.log("SecondaryMarketplace deployed to:", await marketplace.getAddress());

  // 6. Deploy ProfitDistributor
  console.log("\n6. Deploying ProfitDistributor...");
  const ProfitDistributor = await ethers.getContractFactory("ProfitDistributor");
  const profitDistributor = await upgrades.deployProxy(
    ProfitDistributor,
    [deployer.address],
    { kind: "uups" }
  );
  await profitDistributor.waitForDeployment();
  console.log("ProfitDistributor deployed to:", await profitDistributor.getAddress());

  // Summary
  console.log("\n=== Deployment Summary ===");
  console.log("MockIdentityRegistry:", await identityRegistry.getAddress());
  console.log("ComplianceModule:", await complianceModule.getAddress());
  console.log("TradeSukukToken Implementation:", await tokenImplementation.getAddress());
  console.log("MurabahaInvoiceFactory:", await invoiceFactory.getAddress());
  console.log("SecondaryMarketplace:", await marketplace.getAddress());
  console.log("ProfitDistributor:", await profitDistributor.getAddress());

  // Save deployment addresses
  const fs = require("fs");
  const deploymentInfo = {
    network: (await ethers.provider.getNetwork()).name,
    deployer: deployer.address,
    contracts: {
      MockIdentityRegistry: await identityRegistry.getAddress(),
      ComplianceModule: await complianceModule.getAddress(),
      TradeSukukTokenImplementation: await tokenImplementation.getAddress(),
      MurabahaInvoiceFactory: await invoiceFactory.getAddress(),
      SecondaryMarketplace: await marketplace.getAddress(),
      ProfitDistributor: await profitDistributor.getAddress()
    },
    timestamp: new Date().toISOString()
  };

  fs.writeFileSync(
    "deployment-addresses.json",
    JSON.stringify(deploymentInfo, null, 2)
  );
  console.log("\nDeployment addresses saved to deployment-addresses.json");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
