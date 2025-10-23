import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { TradeSukukToken, ComplianceModule, MockIdentityRegistry } from "../typechain-types";

describe("TradeSukukToken", function () {
  let token: TradeSukukToken;
  let complianceModule: ComplianceModule;
  let identityRegistry: MockIdentityRegistry;
  let owner: SignerWithAddress;
  let investor1: SignerWithAddress;
  let investor2: SignerWithAddress;
  let complianceOfficer: SignerWithAddress;

  const AGENT_ROLE = ethers.keccak256(ethers.toUtf8Bytes("AGENT_ROLE"));
  const COMPLIANCE_ROLE = ethers.keccak256(ethers.toUtf8Bytes("COMPLIANCE_ROLE"));

  beforeEach(async function () {
    [owner, investor1, investor2, complianceOfficer] = await ethers.getSigners();

    // Deploy MockIdentityRegistry
    const MockIdentityRegistry = await ethers.getContractFactory("MockIdentityRegistry");
    identityRegistry = await MockIdentityRegistry.deploy(owner.address);

    // Deploy ComplianceModule
    const ComplianceModule = await ethers.getContractFactory("ComplianceModule");
    complianceModule = await upgrades.deployProxy(
      ComplianceModule,
      [true, ethers.parseEther("1000000"), ethers.parseEther("100"), owner.address],
      { kind: "uups" }
    ) as unknown as ComplianceModule;

    // Deploy TradeSukukToken
    const TradeSukukToken = await ethers.getContractFactory("TradeSukukToken");
    token = await upgrades.deployProxy(
      TradeSukukToken,
      [
        "Trade Sukuk Token",
        "TST",
        await complianceModule.getAddress(),
        await identityRegistry.getAddress(),
        "INV-001",
        ethers.parseEther("100000"),
        Math.floor(Date.now() / 1000) + 365 * 24 * 60 * 60,
        500,
        owner.address
      ],
      { kind: "uups" }
    ) as unknown as TradeSukukToken;

    // Register identities
    await identityRegistry.registerIdentity(owner.address, owner.address, "0x5553"); // US
    await identityRegistry.registerIdentity(investor1.address, investor1.address, "0x5553");
    await identityRegistry.registerIdentity(investor2.address, investor2.address, "0x5553");
  });

  describe("Deployment", function () {
    it("Should set the right name and symbol", async function () {
      expect(await token.name()).to.equal("Trade Sukuk Token");
      expect(await token.symbol()).to.equal("TST");
    });

    it("Should set the right asset details", async function () {
      expect(await token.assetIdentifier()).to.equal("INV-001");
      expect(await token.assetValue()).to.equal(ethers.parseEther("100000"));
      expect(await token.profitRate()).to.equal(500);
    });

    it("Should grant roles to owner", async function () {
      expect(await token.hasRole(AGENT_ROLE, owner.address)).to.be.true;
      expect(await token.hasRole(COMPLIANCE_ROLE, owner.address)).to.be.true;
    });
  });

  describe("Minting", function () {
    it("Should mint tokens to verified investors", async function () {
      const mintAmount = ethers.parseEther("1000");
      await token.mint(investor1.address, mintAmount);

      expect(await token.balanceOf(investor1.address)).to.equal(mintAmount);
      expect(await token.totalSupply()).to.equal(mintAmount);
    });

    it("Should fail to mint to unverified investor", async function () {
      const unverified = ethers.Wallet.createRandom().address;
      await expect(
        token.mint(unverified, ethers.parseEther("1000"))
      ).to.be.revertedWithCustomError(token, "InvalidIdentity");
    });

    it("Should fail to mint when token is frozen", async function () {
      await token.setTokenFrozen(true);
      await expect(
        token.mint(investor1.address, ethers.parseEther("1000"))
      ).to.be.revertedWithCustomError(token, "TokenIsFrozen");
    });
  });

  describe("Transfers", function () {
    beforeEach(async function () {
      await token.mint(investor1.address, ethers.parseEther("1000"));
    });

    it("Should transfer tokens between verified investors", async function () {
      const transferAmount = ethers.parseEther("100");
      await token.connect(investor1).transfer(investor2.address, transferAmount);

      expect(await token.balanceOf(investor1.address)).to.equal(ethers.parseEther("900"));
      expect(await token.balanceOf(investor2.address)).to.equal(transferAmount);
    });

    it("Should fail to transfer to unverified address", async function () {
      const unverified = ethers.Wallet.createRandom().address;
      await expect(
        token.connect(investor1).transfer(unverified, ethers.parseEther("100"))
      ).to.be.revertedWithCustomError(token, "InvalidIdentity");
    });

    it("Should fail to transfer when paused", async function () {
      await token.pause();
      await expect(
        token.connect(investor1).transfer(investor2.address, ethers.parseEther("100"))
      ).to.be.reverted;
    });

    it("Should fail to transfer from frozen wallet", async function () {
      await token.setWalletFrozen(investor1.address, true);
      await expect(
        token.connect(investor1).transfer(investor2.address, ethers.parseEther("100"))
      ).to.be.revertedWithCustomError(token, "WalletFrozen");
    });
  });

  describe("Compliance", function () {
    beforeEach(async function () {
      await token.mint(investor1.address, ethers.parseEther("1000"));
    });

    it("Should check transfer compliance", async function () {
      const canTransfer = await token.canTransfer(
        investor1.address,
        investor2.address,
        ethers.parseEther("100")
      );
      expect(canTransfer).to.be.true;
    });

    it("Should allow forced transfer by compliance officer", async function () {
      const transferId = ethers.keccak256(ethers.toUtf8Bytes("transfer-1"));
      await token.forcedTransfer(
        investor1.address,
        investor2.address,
        ethers.parseEther("100"),
        transferId
      );

      expect(await token.balanceOf(investor2.address)).to.equal(ethers.parseEther("100"));
    });

    it("Should prevent duplicate forced transfers", async function () {
      const transferId = ethers.keccak256(ethers.toUtf8Bytes("transfer-1"));
      await token.forcedTransfer(
        investor1.address,
        investor2.address,
        ethers.parseEther("100"),
        transferId
      );

      await expect(
        token.forcedTransfer(
          investor1.address,
          investor2.address,
          ethers.parseEther("100"),
          transferId
        )
      ).to.be.revertedWithCustomError(token, "ForcedTransferAlreadyExecuted");
    });
  });

  describe("Asset Management", function () {
    it("Should update asset details", async function () {
      const newMaturityDate = Math.floor(Date.now() / 1000) + 2 * 365 * 24 * 60 * 60;
      await token.updateAssetDetails(
        "INV-002",
        ethers.parseEther("200000"),
        newMaturityDate,
        600
      );

      expect(await token.assetIdentifier()).to.equal("INV-002");
      expect(await token.assetValue()).to.equal(ethers.parseEther("200000"));
      expect(await token.profitRate()).to.equal(600);
    });
  });

  describe("Emergency Functions", function () {
    it("Should pause and unpause", async function () {
      await token.pause();
      expect(await token.paused()).to.be.true;

      await token.unpause();
      expect(await token.paused()).to.be.false;
    });

    it("Should freeze and unfreeze token", async function () {
      await token.setTokenFrozen(true);
      expect(await token.isFrozen()).to.be.true;

      await token.setTokenFrozen(false);
      expect(await token.isFrozen()).to.be.false;
    });
  });
});
