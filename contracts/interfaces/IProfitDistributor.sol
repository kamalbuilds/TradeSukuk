// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IProfitDistributor
 * @notice Interface for automated profit distribution to Sukuk token holders
 * @dev Implements pro-rata distribution, payment tracking, and redemption mechanisms
 * @custom:security-contact security@tradesukuk.com
 */
interface IProfitDistributor {

    // ============ Enums ============

    /**
     * @notice Distribution status
     */
    enum DistributionStatus {
        SCHEDULED,          // Distribution scheduled but not yet executed
        PENDING,            // Payment received, awaiting distribution
        IN_PROGRESS,        // Currently distributing to token holders
        COMPLETED,          // All distributions completed
        FAILED,             // Distribution failed, funds returned
        CANCELLED           // Distribution cancelled by admin
    }

    /**
     * @notice Payment source type
     */
    enum PaymentSource {
        INVOICE_PAYMENT,    // Payment from invoice buyer
        PROFIT_SHARE,       // Profit from underlying asset
        DIVIDEND,           // Periodic dividend payment
        REDEMPTION,         // Token redemption at maturity
        EARLY_REDEMPTION,   // Early exit redemption
        OTHER               // Other payment sources
    }

    // ============ Structs ============

    /**
     * @notice Distribution event details
     * @param distributionId Unique identifier for distribution
     * @param token Security token receiving distribution
     * @param totalAmount Total amount to distribute
     * @param distributedAmount Amount already distributed
     * @param profitPerToken Profit amount per token unit
     * @param paymentSource Source of the payment
     * @param status Current distribution status
     * @param scheduledDate Scheduled distribution date
     * @param executedDate Actual execution date
     * @param recipientCount Number of token holders receiving distribution
     * @param metadataHash IPFS hash of distribution documentation
     */
    struct Distribution {
        uint256 distributionId;
        address token;
        uint256 totalAmount;
        uint256 distributedAmount;
        uint256 profitPerToken;
        PaymentSource paymentSource;
        DistributionStatus status;
        uint256 scheduledDate;
        uint256 executedDate;
        uint256 recipientCount;
        bytes32 metadataHash;
    }

    /**
     * @notice Individual holder claim information
     * @param holder Token holder address
     * @param tokenBalance Balance at snapshot
     * @param claimableAmount Amount eligible to claim
     * @param claimedAmount Amount already claimed
     * @param lastClaimDate Last claim timestamp
     * @param claimCount Number of claims made
     */
    struct HolderClaim {
        address holder;
        uint256 tokenBalance;
        uint256 claimableAmount;
        uint256 claimedAmount;
        uint256 lastClaimDate;
        uint256 claimCount;
    }

    /**
     * @notice Payment receipt record
     * @param receiptId Unique receipt identifier
     * @param token Token associated with payment
     * @param payer Address that sent payment
     * @param amount Payment amount received
     * @param paymentSource Source/type of payment
     * @param receivedDate Timestamp of receipt
     * @param processed Whether payment has been distributed
     * @param distributionId Associated distribution ID (0 if not yet distributed)
     */
    struct PaymentReceipt {
        uint256 receiptId;
        address token;
        address payer;
        uint256 amount;
        PaymentSource paymentSource;
        uint256 receivedDate;
        bool processed;
        uint256 distributionId;
    }

    /**
     * @notice Redemption configuration
     * @param token Token contract address
     * @param redemptionEnabled Whether redemption is active
     * @param redemptionPrice Price per token for redemption
     * @param maturityDate Scheduled maturity date
     * @param earlyRedemptionAllowed Whether early redemption permitted
     * @param earlyRedemptionPenalty Penalty percentage for early redemption (basis points)
     * @param minRedemptionAmount Minimum tokens for redemption
     * @param totalRedeemed Total tokens redeemed to date
     */
    struct RedemptionConfig {
        address token;
        bool redemptionEnabled;
        uint256 redemptionPrice;
        uint256 maturityDate;
        bool earlyRedemptionAllowed;
        uint256 earlyRedemptionPenalty;
        uint256 minRedemptionAmount;
        uint256 totalRedeemed;
    }

    // ============ Events ============

    /**
     * @notice Emitted when payment is received
     * @param receiptId Unique receipt identifier
     * @param token Token receiving payment
     * @param payer Address that sent payment
     * @param amount Payment amount
     * @param paymentSource Type of payment
     */
    event PaymentReceived(
        uint256 indexed receiptId,
        address indexed token,
        address indexed payer,
        uint256 amount,
        PaymentSource paymentSource
    );

    /**
     * @notice Emitted when distribution is scheduled
     * @param distributionId Distribution identifier
     * @param token Token receiving distribution
     * @param totalAmount Total amount to distribute
     * @param scheduledDate Scheduled execution date
     */
    event DistributionScheduled(
        uint256 indexed distributionId,
        address indexed token,
        uint256 totalAmount,
        uint256 scheduledDate
    );

    /**
     * @notice Emitted when distribution begins execution
     * @param distributionId Distribution identifier
     * @param profitPerToken Calculated profit per token
     * @param recipientCount Number of recipients
     */
    event DistributionStarted(
        uint256 indexed distributionId,
        uint256 profitPerToken,
        uint256 recipientCount
    );

    /**
     * @notice Emitted when distribution is completed
     * @param distributionId Distribution identifier
     * @param totalDistributed Total amount distributed
     * @param recipientCount Number of recipients who received payment
     */
    event DistributionCompleted(
        uint256 indexed distributionId,
        uint256 totalDistributed,
        uint256 recipientCount
    );

    /**
     * @notice Emitted when token holder claims profit
     * @param distributionId Distribution identifier
     * @param holder Token holder address
     * @param amount Amount claimed
     */
    event ProfitClaimed(
        uint256 indexed distributionId,
        address indexed holder,
        uint256 amount
    );

    /**
     * @notice Emitted when tokens are redeemed
     * @param token Token contract address
     * @param holder Token holder redeeming
     * @param tokenAmount Number of tokens redeemed
     * @param redemptionValue Value paid for redemption
     * @param isEarlyRedemption Whether this was early redemption
     * @param penalty Penalty amount (if early redemption)
     */
    event TokensRedeemed(
        address indexed token,
        address indexed holder,
        uint256 tokenAmount,
        uint256 redemptionValue,
        bool isEarlyRedemption,
        uint256 penalty
    );

    /**
     * @notice Emitted when redemption configuration is updated
     * @param token Token contract address
     * @param redemptionPrice New redemption price
     * @param maturityDate Maturity date
     */
    event RedemptionConfigured(
        address indexed token,
        uint256 redemptionPrice,
        uint256 maturityDate
    );

    /**
     * @notice Emitted when distribution fails
     * @param distributionId Distribution identifier
     * @param reason Failure reason
     */
    event DistributionFailed(
        uint256 indexed distributionId,
        string reason
    );

    // ============ Payment Receipt Functions ============

    /**
     * @notice Receives payment for distribution
     * @dev Called when invoice payment or profit is received
     * @param token Token to receive distribution
     * @param paymentSource Type/source of payment
     * @param metadataHash IPFS hash of payment documentation
     * @return receiptId Unique identifier for payment receipt
     */
    function receivePayment(
        address token,
        PaymentSource paymentSource,
        bytes32 metadataHash
    ) external payable returns (uint256 receiptId);

    /**
     * @notice Returns payment receipt details
     * @param receiptId Receipt identifier
     * @return PaymentReceipt struct with receipt information
     */
    function getPaymentReceipt(uint256 receiptId)
        external
        view
        returns (PaymentReceipt memory);

    /**
     * @notice Returns all unprocessed payment receipts for a token
     * @param token Token contract address
     * @return Array of PaymentReceipt structs
     */
    function getUnprocessedPayments(address token)
        external
        view
        returns (PaymentReceipt[] memory);

    /**
     * @notice Returns total unprocessed payment amount for a token
     * @param token Token contract address
     * @return Total amount awaiting distribution
     */
    function getUnprocessedAmount(address token) external view returns (uint256);

    // ============ Distribution Functions ============

    /**
     * @notice Schedules a profit distribution
     * @dev Creates distribution event for future execution
     * @param token Token to receive distribution
     * @param totalAmount Amount to distribute
     * @param scheduledDate When to execute distribution
     * @param paymentSource Source of the payment
     * @param metadataHash IPFS hash of distribution documentation
     * @return distributionId Unique identifier for distribution
     */
    function scheduleDistribution(
        address token,
        uint256 totalAmount,
        uint256 scheduledDate,
        PaymentSource paymentSource,
        bytes32 metadataHash
    ) external returns (uint256 distributionId);

    /**
     * @notice Executes a scheduled distribution
     * @dev Calculates pro-rata amounts and distributes to all token holders
     * @param distributionId Distribution identifier
     */
    function executeDistribution(uint256 distributionId) external;

    /**
     * @notice Distributes payment immediately to token holders
     * @dev Combines schedule and execute in single transaction
     * @param token Token to receive distribution
     * @param paymentSource Source of payment
     * @param metadataHash IPFS hash of documentation
     * @return distributionId Unique identifier for distribution
     */
    function distributeImmediately(
        address token,
        PaymentSource paymentSource,
        bytes32 metadataHash
    ) external payable returns (uint256 distributionId);

    /**
     * @notice Calculates pro-rata distribution amounts
     * @dev Used for preview before actual distribution
     * @param token Token contract address
     * @param totalAmount Total amount to distribute
     * @return holders Array of holder addresses
     * @return amounts Array of distribution amounts per holder
     */
    function calculateDistribution(address token, uint256 totalAmount)
        external
        view
        returns (address[] memory holders, uint256[] memory amounts);

    /**
     * @notice Returns distribution details
     * @param distributionId Distribution identifier
     * @return Distribution struct with all distribution information
     */
    function getDistribution(uint256 distributionId)
        external
        view
        returns (Distribution memory);

    /**
     * @notice Returns distributions for a specific token
     * @param token Token contract address
     * @param limit Maximum number of distributions to return
     * @return Array of Distribution structs (most recent first)
     */
    function getDistributionsByToken(address token, uint256 limit)
        external
        view
        returns (Distribution[] memory);

    /**
     * @notice Returns total distributions count for a token
     * @param token Token contract address
     * @return Number of distributions executed
     */
    function getDistributionCount(address token) external view returns (uint256);

    // ============ Claim Functions ============

    /**
     * @notice Allows token holder to claim their profit share
     * @dev Transfers claimable amount to holder's address
     * @param distributionId Distribution identifier
     * @return amount Amount claimed
     */
    function claimProfit(uint256 distributionId) external returns (uint256 amount);

    /**
     * @notice Claims profit from multiple distributions
     * @param distributionIds Array of distribution identifiers
     * @return totalAmount Total amount claimed across all distributions
     */
    function batchClaimProfit(uint256[] calldata distributionIds)
        external
        returns (uint256 totalAmount);

    /**
     * @notice Returns claimable amount for a holder in a distribution
     * @param distributionId Distribution identifier
     * @param holder Token holder address
     * @return Claimable profit amount
     */
    function getClaimableAmount(uint256 distributionId, address holder)
        external
        view
        returns (uint256);

    /**
     * @notice Returns total claimable amount across all distributions
     * @param token Token contract address
     * @param holder Token holder address
     * @return Total claimable amount
     */
    function getTotalClaimable(address token, address holder)
        external
        view
        returns (uint256);

    /**
     * @notice Returns holder's claim information for a distribution
     * @param distributionId Distribution identifier
     * @param holder Token holder address
     * @return HolderClaim struct with claim details
     */
    function getHolderClaim(uint256 distributionId, address holder)
        external
        view
        returns (HolderClaim memory);

    /**
     * @notice Checks if holder has unclaimed profits
     * @param token Token contract address
     * @param holder Token holder address
     * @return True if unclaimed profits exist, false otherwise
     */
    function hasUnclaimedProfits(address token, address holder)
        external
        view
        returns (bool);

    // ============ Redemption Functions ============

    /**
     * @notice Configures redemption parameters for a token
     * @dev Only callable by authorized administrator
     * @param token Token contract address
     * @param redemptionPrice Price per token for redemption
     * @param maturityDate Scheduled maturity date
     * @param earlyRedemptionAllowed Whether early redemption permitted
     * @param earlyRedemptionPenalty Penalty percentage (basis points)
     * @param minRedemptionAmount Minimum tokens for redemption
     */
    function configureRedemption(
        address token,
        uint256 redemptionPrice,
        uint256 maturityDate,
        bool earlyRedemptionAllowed,
        uint256 earlyRedemptionPenalty,
        uint256 minRedemptionAmount
    ) external;

    /**
     * @notice Enables or disables redemption for a token
     * @param token Token contract address
     * @param enabled Whether redemption should be enabled
     */
    function setRedemptionEnabled(address token, bool enabled) external;

    /**
     * @notice Redeems tokens for underlying value
     * @dev Burns tokens and transfers redemption value to holder
     * @param token Token contract address
     * @param tokenAmount Number of tokens to redeem
     * @return redemptionValue Amount returned to holder
     * @return penalty Penalty amount (if early redemption)
     */
    function redeemTokens(address token, uint256 tokenAmount)
        external
        returns (uint256 redemptionValue, uint256 penalty);

    /**
     * @notice Calculates redemption value for token amount
     * @dev Includes penalty calculation for early redemption
     * @param token Token contract address
     * @param tokenAmount Number of tokens to redeem
     * @return grossValue Value before penalty
     * @return penalty Penalty amount (if applicable)
     * @return netValue Net value after penalty
     */
    function calculateRedemptionValue(address token, uint256 tokenAmount)
        external
        view
        returns (
            uint256 grossValue,
            uint256 penalty,
            uint256 netValue
        );

    /**
     * @notice Returns redemption configuration for a token
     * @param token Token contract address
     * @return RedemptionConfig struct with redemption parameters
     */
    function getRedemptionConfig(address token)
        external
        view
        returns (RedemptionConfig memory);

    /**
     * @notice Checks if token has reached maturity
     * @param token Token contract address
     * @return True if maturity date has passed, false otherwise
     */
    function isMatured(address token) external view returns (bool);

    /**
     * @notice Returns days until maturity
     * @param token Token contract address
     * @return Number of days (can be negative if past maturity)
     */
    function getDaysUntilMaturity(address token) external view returns (int256);

    // ============ Administrative Functions ============

    /**
     * @notice Cancels a scheduled distribution
     * @dev Only callable before distribution execution
     * @param distributionId Distribution identifier
     * @param reason Cancellation reason
     */
    function cancelDistribution(uint256 distributionId, string calldata reason) external;

    /**
     * @notice Sets snapshot contract for balance tracking
     * @param snapshotContract Address of snapshot contract
     */
    function setSnapshotContract(address snapshotContract) external;

    /**
     * @notice Returns current snapshot contract address
     * @return Address of snapshot contract
     */
    function getSnapshotContract() external view returns (address);

    /**
     * @notice Withdraws unclaimed profits after expiry period
     * @dev Only callable by admin after claim expiry
     * @param distributionId Distribution identifier
     * @param recipient Address to receive unclaimed funds
     */
    function withdrawUnclaimedProfits(
        uint256 distributionId,
        address recipient
    ) external;

    /**
     * @notice Returns total unclaimed amount for a distribution
     * @param distributionId Distribution identifier
     * @return Unclaimed profit amount
     */
    function getUnclaimedAmount(uint256 distributionId)
        external
        view
        returns (uint256);

    /**
     * @notice Pauses all distributions and redemptions
     * @dev Emergency function, only callable by admin
     */
    function pause() external;

    /**
     * @notice Resumes distributions and redemptions
     */
    function unpause() external;

    /**
     * @notice Checks if contract is paused
     * @return True if paused, false otherwise
     */
    function isPaused() external view returns (bool);
}
