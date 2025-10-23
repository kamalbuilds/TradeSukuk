import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import {
  MurabahaInvoiceFactory,
  TradeSukukToken,
  ComplianceModule,
  MockIdentityRegistry
} from "../typechain-types";

describe("MurabahaInvoiceFactory", function () {
  let factory: MurabahaInvoiceFactory;
  let tokenImplementation: TradeSukukToken;
  let complianceModule: ComplianceModule;
  let identityRegistry: MockIdentityRegistry;
  let owner: SignerWithAddress;
  let issuer: SignerWithAddress;

  const ISSUER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("ISSUER_ROLE"));

  beforeEach(async function () {
    [owner, issuer] = await ethers.getSigners();

    // Deploy MockIdentityRegistry
    const MockIdentityRegistry = await ethers.getContractFactory("MockIdentityRegistry");
    identityRegistry = await MockIdentityRegistry.deploy(owner.address);

    // Register issuer identity
    await identityRegistry.registerIdentity(issuer.address, issuer.address, "0x5553");

    // Deploy ComplianceModule
    const ComplianceModule = await ethers.getContractFactory("ComplianceModule");
    complianceModule = await upgrades.deployProxy(
      ComplianceModule,
      [true, ethers.parseEther("1000000"), ethers.parseEther("100"), owner.address],
      { kind: "uups" }
    ) as unknown as ComplianceModule;

    // Deploy TradeSukukToken implementation
    const TradeSukukToken = await ethers.getContractFactory("TradeSukukToken");
    tokenImplementation = await TradeSukukToken.deploy();

    // Deploy MurabahaInvoiceFactory
    const MurabahaInvoiceFactory = await ethers.getContractFactory("MurabahaInvoiceFactory");
    factory = await upgrades.deployProxy(
      MurabahaInvoiceFactory,
      [
        await tokenImplementation.getAddress(),
        await complianceModule.getAddress(),
        await identityRegistry.getAddress(),
        owner.address
      ],
      { kind: "uups" }
    ) as unknown as MurabahaInvoiceFactory;

    // Grant ISSUER_ROLE to issuer
    await factory.grantRole(ISSUER_ROLE, issuer.address);
  });

  describe("Invoice Creation", function () {
    it("Should create invoice token successfully", async function () {
      const maturityDate = Math.floor(Date.now() / 1000) + 365 * 24 * 60 * 60;

      const tx = await factory.connect(issuer).createInvoiceToken(
        "INV-001",
        "Murabaha Invoice Token 001",
        "MIT001",
        ethers.parseEther("100000"),
        500,
        maturityDate,
        "Trade finance for electronics purchase",
        ethers.parseEther("10000")
      );

      const receipt = await tx.wait();
      const event = receipt?.logs.find(
        (log: any) => log.fragment?.name === "InvoiceTokenCreated"
      );

      expect(event).to.not.be.undefined;

      const invoice = await factory.getInvoice("INV-001");
      expect(invoice.invoiceId).to.equal("INV-001");
      expect(invoice.issuer).to.equal(issuer.address);
      expect(invoice.assetValue).to.equal(ethers.parseEther("100000"));
      expect(invoice.profitMargin).to.equal(500);
      expect(invoice.isActive).to.be.true;
    });

    it("Should fail to create duplicate invoice", async function () {
      const maturityDate = Math.floor(Date.now() / 1000) + 365 * 24 * 60 * 60;

      await factory.connect(issuer).createInvoiceToken(
        "INV-001",
        "Token 1",
        "T1",
        ethers.parseEther("100000"),
        500,
        maturityDate,
        "Description",
        0
      );

      await expect(
        factory.connect(issuer).createInvoiceToken(
          "INV-001",
          "Token 2",
          "T2",
          ethers.parseEther("100000"),
          500,
          maturityDate,
          "Description",
          0
        )
      ).to.be.revertedWithCustomError(factory, "InvoiceAlreadyExists");
    });

    it("Should fail with invalid maturity date", async function () {
      const pastDate = Math.floor(Date.now() / 1000) - 1000;

      await expect(
        factory.connect(issuer).createInvoiceToken(
          "INV-001",
          "Token",
          "TKN",
          ethers.parseEther("100000"),
          500,
          pastDate,
          "Description",
          0
        )
      ).to.be.revertedWithCustomError(factory, "InvalidMaturityDate");
    });

    it("Should calculate maturity value correctly", async function () {
      const maturityDate = Math.floor(Date.now() / 1000) + 365 * 24 * 60 * 60;
      const assetValue = ethers.parseEther("100000");
      const profitMargin = 500; // 5%

      await factory.connect(issuer).createInvoiceToken(
        "INV-001",
        "Token",
        "TKN",
        assetValue,
        profitMargin,
        maturityDate,
        "Description",
        0
      );

      const maturityValue = await factory.calculateMaturityValue("INV-001");
      const expectedProfit = (assetValue * BigInt(profitMargin)) / 10000n;
      expect(maturityValue).to.equal(assetValue + expectedProfit);
    });
  });

  describe("Invoice Management", function () {
    let tokenAddress: string;

    beforeEach(async function () {
      const maturityDate = Math.floor(Date.now() / 1000) + 365 * 24 * 60 * 60;
      const tx = await factory.connect(issuer).createInvoiceToken(
        "INV-001",
        "Token",
        "TKN",
        ethers.parseEther("100000"),
        500,
        maturityDate,
        "Description",
        0
      );
      const receipt = await tx.wait();
      const invoice = await factory.getInvoice("INV-001");
      tokenAddress = invoice.tokenAddress;
    });

    it("Should deactivate invoice", async function () {
      await factory.connect(issuer).deactivateInvoice("INV-001");

      const invoice = await factory.getInvoice("INV-001");
      expect(invoice.isActive).to.be.false;

      // Check that token is frozen
      const token = await ethers.getContractAt("TradeSukukToken", tokenAddress);
      expect(await token.isFrozen()).to.be.true;
    });

    it("Should get invoice by token address", async function () {
      const invoice = await factory.getInvoiceByToken(tokenAddress);
      expect(invoice.invoiceId).to.equal("INV-001");
    });

    it("Should get active invoices", async function () {
      const activeInvoices = await factory.getActiveInvoices(0, 10);
      expect(activeInvoices.length).to.equal(1);
      expect(activeInvoices[0].invoiceId).to.equal("INV-001");
    });
  });

  describe("Configuration", function () {
    it("Should update token implementation", async function () {
      const newImplementation = await ethers.Wallet.createRandom().address;
      await factory.setTokenImplementation(newImplementation);
      expect(await factory.tokenImplementation()).to.equal(newImplementation);
    });

    it("Should update compliance module", async function () {
      const newModule = await ethers.Wallet.createRandom().address;
      await factory.setDefaultComplianceModule(newModule);
      expect(await factory.defaultComplianceModule()).to.equal(newModule);
    });
  });
});
