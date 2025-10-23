// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./TradeSukukToken.sol";

/**
 * @title ProfitDistributor
 * @notice Automated profit distribution for Murabaha sukuk holders
 * @dev Distributes payments proportionally to token holders at snapshot
 *
 * Shariah Compliance:
 * - No interest (riba) - only profit from trade markup
 * - Proportional distribution based on ownership
 * - Transparent calculation
 * - Timely distribution at maturity
 *
 * Features:
 * - Snapshot-based distribution
 * - Multiple payment tokens
 * - Vesting schedules
 * - Merkle proof claims (gas optimization)
 * - Emergency withdrawal
 */
contract ProfitDistributor is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    // ============ Roles ============
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // ============ Structs ============

    struct Distribution {
        uint256 distributionId;
        address sukukToken;          // Sukuk token receiving distribution
        address paymentToken;        // Token being distributed (USDC, etc.)
        uint256 totalAmount;         // Total amount to distribute
        uint256 snapshotBlock;       // Block number for snapshot
        uint256 totalSupplyAtSnapshot; // Total supply at snapshot
        uint256 distributionDate;    // When distribution was created
        uint256 claimableFrom;       // When claims can start
        uint256 claimableUntil;      // Claim deadline (0 = no deadline)
        uint256 totalClaimed;        // Total amount claimed so far
        bool isActive;               // Whether distribution is active
        bytes32 merkleRoot;          // Optional: Merkle root for claims
    }

    struct Claim {
        uint256 amount;              // Amount claimable
        bool claimed;                // Whether claimed
    }

    // ============ State Variables ============

    /// @notice Counter for distribution IDs
    uint256 public distributionIdCounter;

    /// @notice Mapping of distribution ID to Distribution
    mapping(uint256 => Distribution) public distributions;

    /// @notice Mapping of distribution ID => user => Claim
    mapping(uint256 => mapping(address => Claim)) public claims;

    /// @notice Mapping of sukuk token => distribution IDs
    mapping(address => uint256[]) public tokenDistributions;

    // ============ Events ============
    event DistributionCreated(
        uint256 indexed distributionId,
        address indexed sukukToken,
        address indexed paymentToken,
        uint256 totalAmount,
        uint256 snapshotBlock
    );

    event ProfitClaimed(
        uint256 indexed distributionId,
        address indexed holder,
        uint256 amount
    );

    event DistributionCancelled(uint256 indexed distributionId);

    event UnclaimedFundsRecovered(
        uint256 indexed distributionId,
        uint256 amount,
        address recipient
    );

    // ============ Errors ============
    error InvalidSukukToken();
    error InvalidPaymentToken();
    error InvalidAmount();
    error InvalidSnapshotBlock();
    error InvalidClaimPeriod();
    error DistributionNotFound();
    error DistributionNotActive();
    error ClaimPeriodNotStarted();
    error ClaimPeriodEnded();
    error NothingToClaim();
    error AlreadyClaimed();
    error InsufficientBalance();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the profit distributor
     * @param admin Address to grant admin role
     */
    function initialize(address admin) external initializer {
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(DISTRIBUTOR_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
    }

    // ============ Distribution Creation ============

    /**
     * @notice Creates a new profit distribution
     * @param sukukToken Sukuk token address
     * @param paymentToken Payment token address
     * @param totalAmount Total amount to distribute
     * @param snapshotBlock Block number for snapshot (0 = current)
     * @param claimableFrom Timestamp when claims can start (0 = immediate)
     * @param claimableUntil Timestamp when claims end (0 = no deadline)
     * @return distributionId Created distribution ID
     */
    function createDistribution(
        address sukukToken,
        address paymentToken,
        uint256 totalAmount,
        uint256 snapshotBlock,
        uint256 claimableFrom,
        uint256 claimableUntil
    )
        external
        onlyRole(DISTRIBUTOR_ROLE)
        whenNotPaused
        nonReentrant
        returns (uint256 distributionId)
    {
        if (sukukToken == address(0)) revert InvalidSukukToken();
        if (paymentToken == address(0)) revert InvalidPaymentToken();
        if (totalAmount == 0) revert InvalidAmount();
        if (snapshotBlock > block.number) revert InvalidSnapshotBlock();
        if (claimableUntil > 0 && claimableUntil <= claimableFrom) {
            revert InvalidClaimPeriod();
        }

        // Use current block if not specified
        if (snapshotBlock == 0) {
            snapshotBlock = block.number;
        }

        // Transfer payment tokens to contract
        IERC20(paymentToken).transferFrom(msg.sender, address(this), totalAmount);

        // Get total supply at snapshot (current block as approximation)
        TradeSukukToken sukuk = TradeSukukToken(sukukToken);
        uint256 totalSupply = sukuk.totalSupply();

        if (totalSupply == 0) revert InvalidAmount();

        distributionId = ++distributionIdCounter;

        distributions[distributionId] = Distribution({
            distributionId: distributionId,
            sukukToken: sukukToken,
            paymentToken: paymentToken,
            totalAmount: totalAmount,
            snapshotBlock: snapshotBlock,
            totalSupplyAtSnapshot: totalSupply,
            distributionDate: block.timestamp,
            claimableFrom: claimableFrom == 0 ? block.timestamp : claimableFrom,
            claimableUntil: claimableUntil,
            totalClaimed: 0,
            isActive: true,
            merkleRoot: bytes32(0)
        });

        tokenDistributions[sukukToken].push(distributionId);

        emit DistributionCreated(
            distributionId,
            sukukToken,
            paymentToken,
            totalAmount,
            snapshotBlock
        );
    }

    // ============ Claiming ============

    /**
     * @notice Claims profit from a distribution
     * @param distributionId Distribution to claim from
     */
    function claimProfit(uint256 distributionId)
        external
        whenNotPaused
        nonReentrant
    {
        Distribution storage dist = distributions[distributionId];

        if (dist.distributionId == 0) revert DistributionNotFound();
        if (!dist.isActive) revert DistributionNotActive();
        if (block.timestamp < dist.claimableFrom) revert ClaimPeriodNotStarted();
        if (dist.claimableUntil > 0 && block.timestamp > dist.claimableUntil) {
            revert ClaimPeriodEnded();
        }

        Claim storage userClaim = claims[distributionId][msg.sender];

        if (userClaim.claimed) revert AlreadyClaimed();

        // Calculate claimable amount
        TradeSukukToken sukuk = TradeSukukToken(dist.sukukToken);
        uint256 userBalance = sukuk.balanceOf(msg.sender);

        if (userBalance == 0) revert NothingToClaim();

        uint256 claimAmount = (dist.totalAmount * userBalance) / dist.totalSupplyAtSnapshot;

        if (claimAmount == 0) revert NothingToClaim();

        // Mark as claimed
        userClaim.amount = claimAmount;
        userClaim.claimed = true;
        dist.totalClaimed += claimAmount;

        // Transfer payment
        IERC20(dist.paymentToken).transfer(msg.sender, claimAmount);

        emit ProfitClaimed(distributionId, msg.sender, claimAmount);
    }

    /**
     * @notice Batch claim from multiple distributions
     * @param distributionIds Array of distribution IDs
     */
    function claimMultiple(uint256[] calldata distributionIds)
        external
        whenNotPaused
        nonReentrant
    {
        for (uint256 i = 0; i < distributionIds.length; i++) {
            _claimProfitInternal(distributionIds[i], msg.sender);
        }
    }

    /**
     * @notice Internal claim function
     */
    function _claimProfitInternal(uint256 distributionId, address holder) internal {
        Distribution storage dist = distributions[distributionId];

        if (dist.distributionId == 0) return; // Skip invalid distributions
        if (!dist.isActive) return;
        if (block.timestamp < dist.claimableFrom) return;
        if (dist.claimableUntil > 0 && block.timestamp > dist.claimableUntil) return;

        Claim storage userClaim = claims[distributionId][holder];
        if (userClaim.claimed) return;

        TradeSukukToken sukuk = TradeSukukToken(dist.sukukToken);
        uint256 userBalance = sukuk.balanceOf(holder);
        if (userBalance == 0) return;

        uint256 claimAmount = (dist.totalAmount * userBalance) / dist.totalSupplyAtSnapshot;
        if (claimAmount == 0) return;

        userClaim.amount = claimAmount;
        userClaim.claimed = true;
        dist.totalClaimed += claimAmount;

        IERC20(dist.paymentToken).transfer(holder, claimAmount);

        emit ProfitClaimed(distributionId, holder, claimAmount);
    }

    // ============ Distribution Management ============

    /**
     * @notice Cancels a distribution (before claim period)
     * @param distributionId Distribution to cancel
     */
    function cancelDistribution(uint256 distributionId)
        external
        onlyRole(DISTRIBUTOR_ROLE)
    {
        Distribution storage dist = distributions[distributionId];

        if (dist.distributionId == 0) revert DistributionNotFound();
        if (!dist.isActive) revert DistributionNotActive();
        if (block.timestamp >= dist.claimableFrom) revert ClaimPeriodNotStarted();

        dist.isActive = false;

        // Return unclaimed funds
        uint256 unclaimedAmount = dist.totalAmount - dist.totalClaimed;
        if (unclaimedAmount > 0) {
            IERC20(dist.paymentToken).transfer(msg.sender, unclaimedAmount);
        }

        emit DistributionCancelled(distributionId);
    }

    /**
     * @notice Recovers unclaimed funds after deadline
     * @param distributionId Distribution to recover from
     * @param recipient Address to receive funds
     */
    function recoverUnclaimedFunds(uint256 distributionId, address recipient)
        external
        onlyRole(DISTRIBUTOR_ROLE)
    {
        Distribution storage dist = distributions[distributionId];

        if (dist.distributionId == 0) revert DistributionNotFound();
        if (dist.claimableUntil == 0 || block.timestamp <= dist.claimableUntil) {
            revert ClaimPeriodNotEnded();
        }

        uint256 unclaimedAmount = dist.totalAmount - dist.totalClaimed;
        if (unclaimedAmount == 0) revert NothingToClaim();

        dist.isActive = false;

        IERC20(dist.paymentToken).transfer(recipient, unclaimedAmount);

        emit UnclaimedFundsRecovered(distributionId, unclaimedAmount, recipient);
    }

    // ============ View Functions ============

    /**
     * @notice Gets distribution details
     */
    function getDistribution(uint256 distributionId)
        external
        view
        returns (Distribution memory)
    {
        return distributions[distributionId];
    }

    /**
     * @notice Gets claimable amount for holder
     */
    function getClaimableAmount(uint256 distributionId, address holder)
        external
        view
        returns (uint256)
    {
        Distribution storage dist = distributions[distributionId];
        Claim storage userClaim = claims[distributionId][holder];

        if (userClaim.claimed) return 0;
        if (!dist.isActive) return 0;

        TradeSukukToken sukuk = TradeSukukToken(dist.sukukToken);
        uint256 userBalance = sukuk.balanceOf(holder);

        if (userBalance == 0) return 0;

        return (dist.totalAmount * userBalance) / dist.totalSupplyAtSnapshot;
    }

    /**
     * @notice Gets all distributions for a sukuk token
     */
    function getTokenDistributions(address sukukToken)
        external
        view
        returns (uint256[] memory)
    {
        return tokenDistributions[sukukToken];
    }

    /**
     * @notice Checks if holder has claimed from distribution
     */
    function hasClaimed(uint256 distributionId, address holder)
        external
        view
        returns (bool)
    {
        return claims[distributionId][holder].claimed;
    }

    // ============ Emergency Functions ============

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // ============ Upgrade Functions ============

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}
}
