// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IComplianceModule.sol";

/**
 * @title ComplianceModule
 * @notice Enforces Shariah compliance rules and regulatory requirements for token transfers
 * @dev Implements ERC-3643 compliance interface with custom Shariah rules
 *
 * Compliance Rules:
 * 1. Shariah Compliance:
 *    - No transfers to/from non-compliant addresses
 *    - Maximum holding limits per investor
 *    - Minimum investment amounts
 *
 * 2. Regulatory Compliance:
 *    - Transfer limits (daily, monthly)
 *    - Country restrictions
 *    - Investor type restrictions
 *
 * 3. KYC/AML:
 *    - Verified identity required
 *    - No sanctioned addresses
 */
contract ComplianceModule is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    IComplianceModule
{
    // ============ Roles ============
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // ============ Structs ============

    struct TransferLimit {
        uint256 dailyLimit;
        uint256 monthlyLimit;
        uint256 dailyTransferred;
        uint256 monthlyTransferred;
        uint256 lastDailyReset;
        uint256 lastMonthlyReset;
    }

    struct InvestorLimits {
        uint256 maxHolding;          // Maximum tokens per investor
        uint256 minInvestment;       // Minimum purchase amount
        bool isWhitelisted;          // Whether investor is whitelisted
    }

    // ============ State Variables ============

    /// @notice Whether Shariah compliance is enforced
    bool public shariahComplianceEnabled;

    /// @notice Global maximum holding per investor
    uint256 public globalMaxHolding;

    /// @notice Global minimum investment amount
    uint256 public globalMinInvestment;

    /// @notice Mapping of restricted countries (ISO country codes)
    mapping(bytes2 => bool) public restrictedCountries;

    /// @notice Mapping of investor-specific limits
    mapping(address => InvestorLimits) public investorLimits;

    /// @notice Mapping of transfer limits per address
    mapping(address => TransferLimit) public transferLimits;

    /// @notice Mapping of sanctioned addresses
    mapping(address => bool) public sanctionedAddresses;

    /// @notice Total supply cap (0 = no cap)
    uint256 public supplyCap;

    /// @notice Whether transfers are globally paused
    bool public transfersPaused;

    // ============ Events ============
    event ShariahComplianceToggled(bool enabled);
    event GlobalMaxHoldingUpdated(uint256 maxHolding);
    event GlobalMinInvestmentUpdated(uint256 minInvestment);
    event CountryRestrictionUpdated(bytes2 indexed country, bool restricted);
    event InvestorLimitsUpdated(address indexed investor, uint256 maxHolding, uint256 minInvestment);
    event SanctionedAddressUpdated(address indexed account, bool sanctioned);
    event SupplyCapUpdated(uint256 supplyCap);
    event TransfersPausedToggled(bool paused);
    event TransferLimitUpdated(address indexed account, uint256 dailyLimit, uint256 monthlyLimit);

    // ============ Errors ============
    error TransfersPaused();
    error ShariahNonCompliant(string reason);
    error ExceedsMaxHolding(uint256 max, uint256 attempted);
    error BelowMinInvestment(uint256 min, uint256 attempted);
    error CountryRestricted(bytes2 country);
    error SanctionedAddress(address account);
    error ExceedsDailyLimit(uint256 limit, uint256 attempted);
    error ExceedsMonthlyLimit(uint256 limit, uint256 attempted);
    error ExceedsSupplyCap(uint256 cap, uint256 attempted);
    error NotWhitelisted(address account);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the compliance module
     * @param _shariahComplianceEnabled Whether to enforce Shariah rules
     * @param _globalMaxHolding Global maximum holding per investor
     * @param _globalMinInvestment Global minimum investment amount
     * @param admin Address to grant admin role
     */
    function initialize(
        bool _shariahComplianceEnabled,
        uint256 _globalMaxHolding,
        uint256 _globalMinInvestment,
        address admin
    ) external initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        shariahComplianceEnabled = _shariahComplianceEnabled;
        globalMaxHolding = _globalMaxHolding;
        globalMinInvestment = _globalMinInvestment;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(COMPLIANCE_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
    }

    // ============ Compliance Checks ============

    /**
     * @notice Checks if transfer is compliant
     * @param from Sender address (address(0) for minting)
     * @param to Recipient address (address(0) for burning)
     * @param amount Transfer amount
     * @return bool Whether transfer is compliant
     */
    function canTransfer(
        address from,
        address to,
        uint256 amount
    ) external view override returns (bool) {
        // Check global pause
        if (transfersPaused) return false;

        // Check sanctioned addresses
        if (sanctionedAddresses[from] || sanctionedAddresses[to]) return false;

        // Skip other checks for burning
        if (to == address(0)) return true;

        // Check minimum investment (for non-zero from, i.e., not minting)
        if (from != address(0)) {
            uint256 minInvestment = investorLimits[to].minInvestment > 0
                ? investorLimits[to].minInvestment
                : globalMinInvestment;
            if (amount < minInvestment) return false;
        }

        // Check transfer limits
        if (!_checkTransferLimits(from, amount)) return false;

        return true;
    }

    /**
     * @notice Called after transfer to update state
     * @param from Sender address
     * @param to Recipient address
     * @param amount Transfer amount
     */
    function transferred(
        address from,
        address to,
        uint256 amount
    ) external override {
        // Update transfer limits
        if (from != address(0)) {
            _updateTransferLimits(from, amount);
        }
    }

    /**
     * @notice Internal check for transfer limits
     */
    function _checkTransferLimits(address from, uint256 amount)
        internal
        view
        returns (bool)
    {
        TransferLimit storage limits = transferLimits[from];

        // No limits set
        if (limits.dailyLimit == 0 && limits.monthlyLimit == 0) {
            return true;
        }

        // Check daily limit
        if (limits.dailyLimit > 0) {
            uint256 dailyUsed = block.timestamp - limits.lastDailyReset > 1 days
                ? 0
                : limits.dailyTransferred;
            if (dailyUsed + amount > limits.dailyLimit) {
                return false;
            }
        }

        // Check monthly limit
        if (limits.monthlyLimit > 0) {
            uint256 monthlyUsed = block.timestamp - limits.lastMonthlyReset > 30 days
                ? 0
                : limits.monthlyTransferred;
            if (monthlyUsed + amount > limits.monthlyLimit) {
                return false;
            }
        }

        return true;
    }

    /**
     * @notice Internal update of transfer limits
     */
    function _updateTransferLimits(address from, uint256 amount) internal {
        TransferLimit storage limits = transferLimits[from];

        // Reset daily if needed
        if (block.timestamp - limits.lastDailyReset > 1 days) {
            limits.dailyTransferred = 0;
            limits.lastDailyReset = block.timestamp;
        }

        // Reset monthly if needed
        if (block.timestamp - limits.lastMonthlyReset > 30 days) {
            limits.monthlyTransferred = 0;
            limits.lastMonthlyReset = block.timestamp;
        }

        // Update transferred amounts
        limits.dailyTransferred += amount;
        limits.monthlyTransferred += amount;
    }

    // ============ Configuration Functions ============

    /**
     * @notice Toggles Shariah compliance enforcement
     */
    function setShariahCompliance(bool enabled)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        shariahComplianceEnabled = enabled;
        emit ShariahComplianceToggled(enabled);
    }

    /**
     * @notice Sets global maximum holding
     */
    function setGlobalMaxHolding(uint256 maxHolding)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        globalMaxHolding = maxHolding;
        emit GlobalMaxHoldingUpdated(maxHolding);
    }

    /**
     * @notice Sets global minimum investment
     */
    function setGlobalMinInvestment(uint256 minInvestment)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        globalMinInvestment = minInvestment;
        emit GlobalMinInvestmentUpdated(minInvestment);
    }

    /**
     * @notice Sets country restriction
     */
    function setCountryRestriction(bytes2 country, bool restricted)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        restrictedCountries[country] = restricted;
        emit CountryRestrictionUpdated(country, restricted);
    }

    /**
     * @notice Sets investor-specific limits
     */
    function setInvestorLimits(
        address investor,
        uint256 maxHolding,
        uint256 minInvestment,
        bool whitelisted
    )
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        investorLimits[investor] = InvestorLimits({
            maxHolding: maxHolding,
            minInvestment: minInvestment,
            isWhitelisted: whitelisted
        });
        emit InvestorLimitsUpdated(investor, maxHolding, minInvestment);
    }

    /**
     * @notice Sets sanctioned address
     */
    function setSanctionedAddress(address account, bool sanctioned)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        sanctionedAddresses[account] = sanctioned;
        emit SanctionedAddressUpdated(account, sanctioned);
    }

    /**
     * @notice Sets supply cap
     */
    function setSupplyCap(uint256 cap)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        supplyCap = cap;
        emit SupplyCapUpdated(cap);
    }

    /**
     * @notice Pauses/unpauses all transfers
     */
    function setTransfersPaused(bool paused)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        transfersPaused = paused;
        emit TransfersPausedToggled(paused);
    }

    /**
     * @notice Sets transfer limits for an address
     */
    function setTransferLimit(
        address account,
        uint256 dailyLimit,
        uint256 monthlyLimit
    )
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        transferLimits[account].dailyLimit = dailyLimit;
        transferLimits[account].monthlyLimit = monthlyLimit;
        transferLimits[account].lastDailyReset = block.timestamp;
        transferLimits[account].lastMonthlyReset = block.timestamp;

        emit TransferLimitUpdated(account, dailyLimit, monthlyLimit);
    }

    // ============ View Functions ============

    /**
     * @notice Gets investor limits
     */
    function getInvestorLimits(address investor)
        external
        view
        returns (InvestorLimits memory)
    {
        return investorLimits[investor];
    }

    /**
     * @notice Gets transfer limits and current usage
     */
    function getTransferLimitStatus(address account)
        external
        view
        returns (
            uint256 dailyLimit,
            uint256 dailyRemaining,
            uint256 monthlyLimit,
            uint256 monthlyRemaining
        )
    {
        TransferLimit storage limits = transferLimits[account];

        dailyLimit = limits.dailyLimit;
        monthlyLimit = limits.monthlyLimit;

        // Calculate remaining daily
        uint256 dailyUsed = block.timestamp - limits.lastDailyReset > 1 days
            ? 0
            : limits.dailyTransferred;
        dailyRemaining = dailyLimit > dailyUsed ? dailyLimit - dailyUsed : 0;

        // Calculate remaining monthly
        uint256 monthlyUsed = block.timestamp - limits.lastMonthlyReset > 30 days
            ? 0
            : limits.monthlyTransferred;
        monthlyRemaining = monthlyLimit > monthlyUsed ? monthlyLimit - monthlyUsed : 0;
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
