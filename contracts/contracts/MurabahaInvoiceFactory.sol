// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./TradeSukukToken.sol";

/**
 * @title MurabahaInvoiceFactory
 * @notice Factory contract for creating tokenized Murabaha trade invoices
 * @dev Creates ERC-3643 compliant tokens for each trade invoice with UUPS proxy pattern
 *
 * Shariah Compliance Features:
 * - Each token represents a specific Murabaha contract
 * - Transparent profit margins
 * - Asset-backed tokens only
 * - No interest, only markup on cost
 *
 * Security:
 * - Role-based access control
 * - Pausable for emergencies
 * - Reentrancy protection
 * - Proxy pattern for upgradeability
 */
contract MurabahaInvoiceFactory is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    // ============ Roles ============
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // ============ Structs ============

    /**
     * @notice Murabaha invoice details
     */
    struct InvoiceDetails {
        string invoiceId;           // Unique off-chain invoice identifier
        address tokenAddress;        // Deployed token contract address
        address issuer;              // Entity issuing the invoice token
        uint256 assetValue;          // Total value of goods/services
        uint256 profitMargin;        // Profit in basis points (e.g., 500 = 5%)
        uint256 maturityDate;        // Payment due date
        uint256 createdAt;           // Creation timestamp
        bool isActive;               // Whether invoice is active
        string assetDescription;     // Description of underlying asset
    }

    // ============ State Variables ============

    /// @notice Implementation contract for token proxies
    address public tokenImplementation;

    /// @notice Default compliance module for new tokens
    address public defaultComplianceModule;

    /// @notice Default identity registry for new tokens
    address public defaultIdentityRegistry;

    /// @notice Mapping from invoice ID to invoice details
    mapping(string => InvoiceDetails) public invoices;

    /// @notice Array of all invoice IDs
    string[] public invoiceIds;

    /// @notice Mapping from token address to invoice ID
    mapping(address => string) public tokenToInvoiceId;

    // ============ Events ============
    event InvoiceTokenCreated(
        string indexed invoiceId,
        address indexed tokenAddress,
        address indexed issuer,
        uint256 assetValue,
        uint256 profitMargin,
        uint256 maturityDate
    );

    event InvoiceDeactivated(string indexed invoiceId);
    event TokenImplementationUpdated(address indexed newImplementation);
    event DefaultComplianceModuleUpdated(address indexed newModule);
    event DefaultIdentityRegistryUpdated(address indexed newRegistry);

    // ============ Errors ============
    error InvoiceAlreadyExists(string invoiceId);
    error InvoiceNotFound(string invoiceId);
    error InvalidInvoiceId();
    error InvalidAssetValue();
    error InvalidMaturityDate();
    error InvalidProfitMargin();
    error InvalidAddress();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the factory
     * @param _tokenImplementation Address of TradeSukukToken implementation
     * @param _defaultComplianceModule Default compliance module
     * @param _defaultIdentityRegistry Default identity registry
     * @param admin Address to grant admin role
     */
    function initialize(
        address _tokenImplementation,
        address _defaultComplianceModule,
        address _defaultIdentityRegistry,
        address admin
    ) external initializer {
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        if (_tokenImplementation == address(0)) revert InvalidAddress();
        if (_defaultComplianceModule == address(0)) revert InvalidAddress();
        if (_defaultIdentityRegistry == address(0)) revert InvalidAddress();

        tokenImplementation = _tokenImplementation;
        defaultComplianceModule = _defaultComplianceModule;
        defaultIdentityRegistry = _defaultIdentityRegistry;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ISSUER_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
    }

    // ============ Invoice Creation ============

    /**
     * @notice Creates a new Murabaha invoice token
     * @param invoiceId Unique invoice identifier
     * @param name Token name
     * @param symbol Token symbol
     * @param assetValue Total asset value
     * @param profitMargin Profit margin in basis points
     * @param maturityDate Maturity timestamp
     * @param assetDescription Description of underlying asset
     * @param totalSupply Initial token supply to mint
     * @return tokenAddress Address of created token
     */
    function createInvoiceToken(
        string calldata invoiceId,
        string calldata name,
        string calldata symbol,
        uint256 assetValue,
        uint256 profitMargin,
        uint256 maturityDate,
        string calldata assetDescription,
        uint256 totalSupply
    )
        external
        onlyRole(ISSUER_ROLE)
        whenNotPaused
        nonReentrant
        returns (address tokenAddress)
    {
        // Validation
        if (bytes(invoiceId).length == 0) revert InvalidInvoiceId();
        if (invoices[invoiceId].tokenAddress != address(0)) {
            revert InvoiceAlreadyExists(invoiceId);
        }
        if (assetValue == 0) revert InvalidAssetValue();
        if (maturityDate <= block.timestamp) revert InvalidMaturityDate();
        if (profitMargin == 0 || profitMargin > 10000) revert InvalidProfitMargin(); // Max 100%

        // Deploy proxy
        bytes memory initData = abi.encodeWithSelector(
            TradeSukukToken.initialize.selector,
            name,
            symbol,
            defaultComplianceModule,
            defaultIdentityRegistry,
            invoiceId,
            assetValue,
            maturityDate,
            profitMargin,
            msg.sender
        );

        ERC1967Proxy proxy = new ERC1967Proxy(tokenImplementation, initData);
        tokenAddress = address(proxy);

        // Store invoice details
        invoices[invoiceId] = InvoiceDetails({
            invoiceId: invoiceId,
            tokenAddress: tokenAddress,
            issuer: msg.sender,
            assetValue: assetValue,
            profitMargin: profitMargin,
            maturityDate: maturityDate,
            createdAt: block.timestamp,
            isActive: true,
            assetDescription: assetDescription
        });

        invoiceIds.push(invoiceId);
        tokenToInvoiceId[tokenAddress] = invoiceId;

        // Mint initial supply to issuer
        if (totalSupply > 0) {
            TradeSukukToken(tokenAddress).mint(msg.sender, totalSupply);
        }

        emit InvoiceTokenCreated(
            invoiceId,
            tokenAddress,
            msg.sender,
            assetValue,
            profitMargin,
            maturityDate
        );
    }

    // ============ Invoice Management ============

    /**
     * @notice Deactivates an invoice (e.g., after maturity or default)
     * @param invoiceId Invoice to deactivate
     */
    function deactivateInvoice(string calldata invoiceId)
        external
        onlyRole(ISSUER_ROLE)
    {
        InvoiceDetails storage invoice = invoices[invoiceId];
        if (invoice.tokenAddress == address(0)) revert InvoiceNotFound(invoiceId);

        invoice.isActive = false;

        // Freeze the token
        TradeSukukToken(invoice.tokenAddress).setTokenFrozen(true);

        emit InvoiceDeactivated(invoiceId);
    }

    /**
     * @notice Updates token implementation for future deployments
     * @param newImplementation New implementation address
     */
    function setTokenImplementation(address newImplementation)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (newImplementation == address(0)) revert InvalidAddress();
        tokenImplementation = newImplementation;
        emit TokenImplementationUpdated(newImplementation);
    }

    /**
     * @notice Updates default compliance module
     * @param newModule New compliance module address
     */
    function setDefaultComplianceModule(address newModule)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (newModule == address(0)) revert InvalidAddress();
        defaultComplianceModule = newModule;
        emit DefaultComplianceModuleUpdated(newModule);
    }

    /**
     * @notice Updates default identity registry
     * @param newRegistry New identity registry address
     */
    function setDefaultIdentityRegistry(address newRegistry)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (newRegistry == address(0)) revert InvalidAddress();
        defaultIdentityRegistry = newRegistry;
        emit DefaultIdentityRegistryUpdated(newRegistry);
    }

    // ============ View Functions ============

    /**
     * @notice Gets invoice details by ID
     */
    function getInvoice(string calldata invoiceId)
        external
        view
        returns (InvoiceDetails memory)
    {
        if (invoices[invoiceId].tokenAddress == address(0)) {
            revert InvoiceNotFound(invoiceId);
        }
        return invoices[invoiceId];
    }

    /**
     * @notice Gets invoice details by token address
     */
    function getInvoiceByToken(address tokenAddress)
        external
        view
        returns (InvoiceDetails memory)
    {
        string memory invoiceId = tokenToInvoiceId[tokenAddress];
        if (bytes(invoiceId).length == 0) revert InvoiceNotFound("");
        return invoices[invoiceId];
    }

    /**
     * @notice Gets total number of invoices
     */
    function getInvoiceCount() external view returns (uint256) {
        return invoiceIds.length;
    }

    /**
     * @notice Gets all active invoices
     * @param offset Starting index
     * @param limit Number of results
     */
    function getActiveInvoices(uint256 offset, uint256 limit)
        external
        view
        returns (InvoiceDetails[] memory activeInvoices)
    {
        uint256 count = 0;

        // Count active invoices
        for (uint256 i = 0; i < invoiceIds.length; i++) {
            if (invoices[invoiceIds[i]].isActive) {
                count++;
            }
        }

        // Calculate result size
        uint256 resultSize = limit;
        if (offset >= count) {
            return new InvoiceDetails[](0);
        }
        if (offset + limit > count) {
            resultSize = count - offset;
        }

        // Fill results
        activeInvoices = new InvoiceDetails[](resultSize);
        uint256 currentIndex = 0;
        uint256 resultIndex = 0;

        for (uint256 i = 0; i < invoiceIds.length && resultIndex < resultSize; i++) {
            if (invoices[invoiceIds[i]].isActive) {
                if (currentIndex >= offset) {
                    activeInvoices[resultIndex] = invoices[invoiceIds[i]];
                    resultIndex++;
                }
                currentIndex++;
            }
        }
    }

    /**
     * @notice Calculates expected total value at maturity (asset value + profit)
     * @param invoiceId Invoice identifier
     */
    function calculateMaturityValue(string calldata invoiceId)
        external
        view
        returns (uint256)
    {
        InvoiceDetails memory invoice = invoices[invoiceId];
        if (invoice.tokenAddress == address(0)) revert InvoiceNotFound(invoiceId);

        uint256 profit = (invoice.assetValue * invoice.profitMargin) / 10000;
        return invoice.assetValue + profit;
    }

    // ============ Emergency Functions ============

    /**
     * @notice Pauses factory
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpauses factory
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
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
}
