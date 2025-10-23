// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IComplianceModule.sol";
import "./interfaces/IIdentityRegistry.sol";

/**
 * @title TradeSukukToken
 * @notice ERC-3643 compliant security token for Shariah-compliant trade finance
 * @dev Implements T-REX standard with Polygon ID integration for KYC/AML
 *
 * Features:
 * - ERC-3643 security token standard
 * - Role-based access control (Agent, Compliance Officer, Admin)
 * - Transfer restrictions based on compliance rules
 * - Integration with on-chain identity (Polygon ID)
 * - Emergency pause mechanism
 * - UUPS upgradeable pattern
 *
 * Shariah Compliance:
 * - Represents ownership in real trade assets (Murabaha invoices)
 * - No interest-bearing mechanisms
 * - Transparent asset backing
 */
contract TradeSukukToken is
    Initializable,
    ERC20Upgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    // ============ Roles ============
    bytes32 public constant AGENT_ROLE = keccak256("AGENT_ROLE");
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // ============ State Variables ============
    IComplianceModule public complianceModule;
    IIdentityRegistry public identityRegistry;

    /// @notice Underlying asset identifier (e.g., invoice ID)
    string public assetIdentifier;

    /// @notice Total asset value backing the tokens
    uint256 public assetValue;

    /// @notice Maturity date timestamp
    uint256 public maturityDate;

    /// @notice Expected profit rate (basis points, e.g., 500 = 5%)
    uint256 public profitRate;

    /// @notice Whether token is frozen (post-maturity or default)
    bool public isFrozen;

    /// @notice Mapping of frozen wallets
    mapping(address => bool) private _frozenWallets;

    /// @notice Mapping to track forced transfers
    mapping(bytes32 => bool) private _executedForcedTransfers;

    // ============ Events ============
    event ComplianceModuleSet(address indexed complianceModule);
    event IdentityRegistrySet(address indexed identityRegistry);
    event WalletFrozen(address indexed wallet, bool frozen);
    event TokenFrozen(bool frozen);
    event ForcedTransfer(
        address indexed from,
        address indexed to,
        uint256 amount,
        bytes32 indexed transferId
    );
    event AssetDetailsUpdated(
        string assetIdentifier,
        uint256 assetValue,
        uint256 maturityDate,
        uint256 profitRate
    );

    // ============ Errors ============
    error TransferNotCompliant(string reason);
    error WalletFrozen(address wallet);
    error TokenIsFrozen();
    error InvalidIdentity(address account);
    error MaturityDatePassed();
    error InvalidComplianceModule();
    error InvalidIdentityRegistry();
    error ForcedTransferAlreadyExecuted();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the TradeSukuk token
     * @param name_ Token name
     * @param symbol_ Token symbol
     * @param _complianceModule Address of compliance module
     * @param _identityRegistry Address of identity registry
     * @param _assetIdentifier Unique identifier for underlying asset
     * @param _assetValue Total value of underlying asset
     * @param _maturityDate Maturity timestamp
     * @param _profitRate Expected profit rate in basis points
     * @param admin Address to grant admin role
     */
    function initialize(
        string memory name_,
        string memory symbol_,
        address _complianceModule,
        address _identityRegistry,
        string memory _assetIdentifier,
        uint256 _assetValue,
        uint256 _maturityDate,
        uint256 _profitRate,
        address admin
    ) external initializer {
        __ERC20_init(name_, symbol_);
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        if (_complianceModule == address(0)) revert InvalidComplianceModule();
        if (_identityRegistry == address(0)) revert InvalidIdentityRegistry();

        complianceModule = IComplianceModule(_complianceModule);
        identityRegistry = IIdentityRegistry(_identityRegistry);

        assetIdentifier = _assetIdentifier;
        assetValue = _assetValue;
        maturityDate = _maturityDate;
        profitRate = _profitRate;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(AGENT_ROLE, admin);
        _grantRole(COMPLIANCE_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
    }

    // ============ Minting Functions ============

    /**
     * @notice Mints new tokens (only for agents)
     * @param to Recipient address
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount)
        external
        onlyRole(AGENT_ROLE)
        whenNotPaused
    {
        if (isFrozen) revert TokenIsFrozen();
        if (_frozenWallets[to]) revert WalletFrozen(to);
        if (!identityRegistry.isVerified(to)) revert InvalidIdentity(to);
        if (!complianceModule.canTransfer(address(0), to, amount)) {
            revert TransferNotCompliant("Mint not compliant");
        }

        _mint(to, amount);
        complianceModule.transferred(address(0), to, amount);
    }

    /**
     * @notice Burns tokens from an address
     * @param from Address to burn from
     * @param amount Amount to burn
     */
    function burn(address from, uint256 amount)
        external
        onlyRole(AGENT_ROLE)
    {
        _burn(from, amount);
        complianceModule.transferred(from, address(0), amount);
    }

    // ============ Transfer Functions ============

    /**
     * @notice Transfers tokens with compliance checks
     * @dev Overrides ERC20 transfer with compliance layer
     */
    function transfer(address to, uint256 amount)
        public
        virtual
        override
        whenNotPaused
        returns (bool)
    {
        address owner = _msgSender();
        _compliantTransfer(owner, to, amount);
        return true;
    }

    /**
     * @notice Transfers tokens from an address with compliance checks
     */
    function transferFrom(address from, address to, uint256 amount)
        public
        virtual
        override
        whenNotPaused
        returns (bool)
    {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _compliantTransfer(from, to, amount);
        return true;
    }

    /**
     * @notice Internal compliant transfer with all checks
     */
    function _compliantTransfer(address from, address to, uint256 amount)
        internal
    {
        if (isFrozen) revert TokenIsFrozen();
        if (_frozenWallets[from]) revert WalletFrozen(from);
        if (_frozenWallets[to]) revert WalletFrozen(to);

        if (!identityRegistry.isVerified(from)) revert InvalidIdentity(from);
        if (!identityRegistry.isVerified(to)) revert InvalidIdentity(to);

        if (!complianceModule.canTransfer(from, to, amount)) {
            revert TransferNotCompliant("Transfer restrictions violated");
        }

        _transfer(from, to, amount);
        complianceModule.transferred(from, to, amount);
    }

    /**
     * @notice Forced transfer by compliance officer (for regulatory compliance)
     * @param from Source address
     * @param to Destination address
     * @param amount Amount to transfer
     * @param transferId Unique transfer identifier to prevent replay
     */
    function forcedTransfer(
        address from,
        address to,
        uint256 amount,
        bytes32 transferId
    )
        external
        onlyRole(COMPLIANCE_ROLE)
        returns (bool)
    {
        if (_executedForcedTransfers[transferId]) {
            revert ForcedTransferAlreadyExecuted();
        }

        _executedForcedTransfers[transferId] = true;
        _transfer(from, to, amount);

        emit ForcedTransfer(from, to, amount, transferId);
        return true;
    }

    // ============ Compliance Management ============

    /**
     * @notice Updates compliance module
     * @param newComplianceModule New compliance module address
     */
    function setComplianceModule(address newComplianceModule)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        if (newComplianceModule == address(0)) revert InvalidComplianceModule();
        complianceModule = IComplianceModule(newComplianceModule);
        emit ComplianceModuleSet(newComplianceModule);
    }

    /**
     * @notice Updates identity registry
     * @param newIdentityRegistry New identity registry address
     */
    function setIdentityRegistry(address newIdentityRegistry)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        if (newIdentityRegistry == address(0)) revert InvalidIdentityRegistry();
        identityRegistry = IIdentityRegistry(newIdentityRegistry);
        emit IdentityRegistrySet(newIdentityRegistry);
    }

    /**
     * @notice Freezes or unfreezes a wallet
     * @param wallet Address to freeze/unfreeze
     * @param freeze True to freeze, false to unfreeze
     */
    function setWalletFrozen(address wallet, bool freeze)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        _frozenWallets[wallet] = freeze;
        emit WalletFrozen(wallet, freeze);
    }

    /**
     * @notice Freezes or unfreezes the entire token
     * @param freeze True to freeze, false to unfreeze
     */
    function setTokenFrozen(bool freeze)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        isFrozen = freeze;
        emit TokenFrozen(freeze);
    }

    /**
     * @notice Checks if a wallet is frozen
     */
    function isWalletFrozen(address wallet) external view returns (bool) {
        return _frozenWallets[wallet];
    }

    // ============ Asset Management ============

    /**
     * @notice Updates asset details
     * @param _assetIdentifier New asset identifier
     * @param _assetValue New asset value
     * @param _maturityDate New maturity date
     * @param _profitRate New profit rate
     */
    function updateAssetDetails(
        string memory _assetIdentifier,
        uint256 _assetValue,
        uint256 _maturityDate,
        uint256 _profitRate
    )
        external
        onlyRole(AGENT_ROLE)
    {
        assetIdentifier = _assetIdentifier;
        assetValue = _assetValue;
        maturityDate = _maturityDate;
        profitRate = _profitRate;

        emit AssetDetailsUpdated(_assetIdentifier, _assetValue, _maturityDate, _profitRate);
    }

    // ============ Emergency Functions ============

    /**
     * @notice Pauses all token transfers
     */
    function pause() external onlyRole(COMPLIANCE_ROLE) {
        _pause();
    }

    /**
     * @notice Unpauses token transfers
     */
    function unpause() external onlyRole(COMPLIANCE_ROLE) {
        _unpause();
    }

    // ============ Upgrade Functions ============

    /**
     * @notice Authorizes contract upgrade
     */
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}

    // ============ View Functions ============

    /**
     * @notice Returns token decimals (always 18 for ERC-3643)
     */
    function decimals() public pure override returns (uint8) {
        return 18;
    }

    /**
     * @notice Checks if transfer is compliant
     */
    function canTransfer(address from, address to, uint256 amount)
        external
        view
        returns (bool)
    {
        if (isFrozen || _frozenWallets[from] || _frozenWallets[to]) {
            return false;
        }
        if (!identityRegistry.isVerified(from) || !identityRegistry.isVerified(to)) {
            return false;
        }
        return complianceModule.canTransfer(from, to, amount);
    }
}
