// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IMurabahaInvoice
 * @notice Interface for Murabaha invoice tokenization and lifecycle management
 * @dev Implements Islamic finance Murabaha (cost-plus financing) for invoice factoring
 * @custom:security-contact security@tradesukuk.com
 */
interface IMurabahaInvoice {

    // ============ Enums ============

    /**
     * @notice Lifecycle stages of a Murabaha invoice
     * @dev Controls state transitions and allowed operations
     */
    enum InvoiceStatus {
        DRAFT,              // Invoice created but not yet verified
        VERIFIED,           // Seller and invoice details verified
        TOKENIZED,          // Sukuk tokens created and available for purchase
        FUNDED,             // Fully funded by investors
        ACTIVE,             // Payment period active, awaiting buyer payment
        PAID,               // Buyer has paid the invoice amount
        SETTLED,            // Profit distributed to token holders
        DEFAULTED,          // Payment overdue beyond grace period
        DISPUTED,           // Under dispute resolution
        CANCELLED           // Cancelled before funding
    }

    /**
     * @notice Type of invoice being tokenized
     */
    enum InvoiceType {
        TRADE_INVOICE,      // Standard trade invoice
        SERVICE_INVOICE,    // Service delivery invoice
        SUPPLY_CONTRACT,    // Supply agreement invoice
        EXPORT_INVOICE,     // International export invoice
        GOVERNMENT_CONTRACT // Government purchase order
    }

    // ============ Structs ============

    /**
     * @notice Core invoice details
     * @param invoiceNumber Unique invoice identifier from seller's system
     * @param seller Address of the seller (original creditor)
     * @param buyer Address of the buyer (debtor)
     * @param invoiceType Category of invoice
     * @param costBasis Original invoice amount (seller's cost)
     * @param profitMargin Profit markup percentage (in basis points, e.g., 500 = 5%)
     * @param totalAmount Total amount = costBasis + profit
     * @param issueDate Timestamp when invoice was issued
     * @param dueDate Payment deadline timestamp
     * @param gracePeriod Days after dueDate before default (in seconds)
     */
    struct InvoiceDetails {
        string invoiceNumber;
        address seller;
        address buyer;
        InvoiceType invoiceType;
        uint256 costBasis;
        uint256 profitMargin;
        uint256 totalAmount;
        uint256 issueDate;
        uint256 dueDate;
        uint256 gracePeriod;
    }

    /**
     * @notice Invoice verification and compliance data
     * @param buyerVerified KYC/AML verification status of buyer
     * @param sellerVerified KYC/AML verification status of seller
     * @param invoiceDocumentHash IPFS hash of invoice document
     * @param tradeDocumentHash IPFS hash of supporting trade documents
     * @param shariahApproved Shariah compliance verification status
     * @param complianceOfficer Address that verified compliance
     * @param verificationDate Timestamp of verification
     */
    struct InvoiceVerification {
        bool buyerVerified;
        bool sellerVerified;
        bytes32 invoiceDocumentHash;
        bytes32 tradeDocumentHash;
        bool shariahApproved;
        address complianceOfficer;
        uint256 verificationDate;
    }

    /**
     * @notice Tokenization parameters
     * @param tokenAddress Address of the created security token
     * @param totalTokens Number of tokens representing this invoice
     * @param tokenPrice Price per token in base currency
     * @param minInvestment Minimum investment amount
     * @param maxInvestment Maximum investment amount per investor
     * @param fundingDeadline Deadline for reaching funding target
     * @param currentFunding Amount currently funded
     */
    struct TokenizationInfo {
        address tokenAddress;
        uint256 totalTokens;
        uint256 tokenPrice;
        uint256 minInvestment;
        uint256 maxInvestment;
        uint256 fundingDeadline;
        uint256 currentFunding;
    }

    /**
     * @notice Payment and settlement tracking
     * @param paymentReceived Total amount paid by buyer
     * @param paymentDate Timestamp of payment receipt
     * @param profitGenerated Actual profit realized
     * @param profitDistributed Amount of profit distributed to token holders
     * @param settlementDate Timestamp of final settlement
     */
    struct PaymentInfo {
        uint256 paymentReceived;
        uint256 paymentDate;
        uint256 profitGenerated;
        uint256 profitDistributed;
        uint256 settlementDate;
    }

    // ============ Events ============

    /**
     * @notice Emitted when a new invoice is created
     * @param invoiceId Unique identifier for the invoice
     * @param seller Address of the seller
     * @param buyer Address of the buyer
     * @param costBasis Original invoice amount
     * @param totalAmount Total amount including profit
     */
    event InvoiceCreated(
        uint256 indexed invoiceId,
        address indexed seller,
        address indexed buyer,
        uint256 costBasis,
        uint256 totalAmount
    );

    /**
     * @notice Emitted when invoice is verified and approved
     * @param invoiceId Invoice identifier
     * @param complianceOfficer Address that performed verification
     * @param shariahApproved Whether Shariah compliance was confirmed
     */
    event InvoiceVerified(
        uint256 indexed invoiceId,
        address indexed complianceOfficer,
        bool shariahApproved
    );

    /**
     * @notice Emitted when invoice is tokenized
     * @param invoiceId Invoice identifier
     * @param tokenAddress Address of the created security token
     * @param totalTokens Number of tokens created
     * @param tokenPrice Price per token
     */
    event InvoiceTokenized(
        uint256 indexed invoiceId,
        address indexed tokenAddress,
        uint256 totalTokens,
        uint256 tokenPrice
    );

    /**
     * @notice Emitted when invoice reaches full funding
     * @param invoiceId Invoice identifier
     * @param totalFunding Total amount funded
     * @param timestamp Funding completion time
     */
    event InvoiceFunded(
        uint256 indexed invoiceId,
        uint256 totalFunding,
        uint256 timestamp
    );

    /**
     * @notice Emitted when buyer makes payment
     * @param invoiceId Invoice identifier
     * @param payer Address that made the payment
     * @param amount Payment amount
     * @param timestamp Payment time
     */
    event PaymentReceived(
        uint256 indexed invoiceId,
        address indexed payer,
        uint256 amount,
        uint256 timestamp
    );

    /**
     * @notice Emitted when profit is distributed
     * @param invoiceId Invoice identifier
     * @param profitAmount Total profit distributed
     * @param recipientCount Number of token holders who received profit
     */
    event ProfitDistributed(
        uint256 indexed invoiceId,
        uint256 profitAmount,
        uint256 recipientCount
    );

    /**
     * @notice Emitted when invoice status changes
     * @param invoiceId Invoice identifier
     * @param oldStatus Previous status
     * @param newStatus New status
     */
    event InvoiceStatusChanged(
        uint256 indexed invoiceId,
        InvoiceStatus oldStatus,
        InvoiceStatus newStatus
    );

    /**
     * @notice Emitted when invoice enters default
     * @param invoiceId Invoice identifier
     * @param timestamp Default declaration time
     */
    event InvoiceDefaulted(
        uint256 indexed invoiceId,
        uint256 timestamp
    );

    // ============ Invoice Creation & Lifecycle ============

    /**
     * @notice Creates a new Murabaha invoice
     * @dev Initializes invoice in DRAFT status
     * @param invoiceNumber Unique invoice number from seller's system
     * @param buyer Address of the buyer (debtor)
     * @param invoiceType Type of invoice
     * @param costBasis Original invoice amount
     * @param profitMargin Profit markup in basis points
     * @param dueDate Payment deadline
     * @param gracePeriod Grace period in seconds
     * @param invoiceDocumentHash IPFS hash of invoice document
     * @return invoiceId Unique identifier assigned to the invoice
     */
    function createInvoice(
        string calldata invoiceNumber,
        address buyer,
        InvoiceType invoiceType,
        uint256 costBasis,
        uint256 profitMargin,
        uint256 dueDate,
        uint256 gracePeriod,
        bytes32 invoiceDocumentHash
    ) external returns (uint256 invoiceId);

    /**
     * @notice Verifies invoice and participants for compliance
     * @dev Transitions invoice from DRAFT to VERIFIED
     * @param invoiceId Invoice identifier
     * @param tradeDocumentHash IPFS hash of trade documents
     * @param shariahApproved Shariah compliance confirmation
     */
    function verifyInvoice(
        uint256 invoiceId,
        bytes32 tradeDocumentHash,
        bool shariahApproved
    ) external;

    /**
     * @notice Tokenizes a verified invoice
     * @dev Creates security tokens representing ownership, transitions to TOKENIZED
     * @param invoiceId Invoice identifier
     * @param totalTokens Number of tokens to create
     * @param tokenPrice Price per token in base currency
     * @param minInvestment Minimum investment amount
     * @param maxInvestment Maximum investment per investor
     * @param fundingDeadline Deadline for full funding
     * @return tokenAddress Address of created security token
     */
    function tokenizeInvoice(
        uint256 invoiceId,
        uint256 totalTokens,
        uint256 tokenPrice,
        uint256 minInvestment,
        uint256 maxInvestment,
        uint256 fundingDeadline
    ) external returns (address tokenAddress);

    /**
     * @notice Records funding contribution from investor
     * @dev Called when investor purchases tokens
     * @param invoiceId Invoice identifier
     * @param investor Address of the investor
     * @param amount Investment amount
     */
    function recordFunding(
        uint256 invoiceId,
        address investor,
        uint256 amount
    ) external;

    /**
     * @notice Checks if invoice is fully funded
     * @param invoiceId Invoice identifier
     * @return True if funding target reached, false otherwise
     */
    function isFullyFunded(uint256 invoiceId) external view returns (bool);

    /**
     * @notice Activates invoice after full funding
     * @dev Transfers funds to seller, transitions to ACTIVE
     * @param invoiceId Invoice identifier
     */
    function activateInvoice(uint256 invoiceId) external;

    // ============ Payment & Settlement ============

    /**
     * @notice Records payment from buyer
     * @dev Can be called by buyer or payment processor
     * @param invoiceId Invoice identifier
     * @param amount Payment amount
     */
    function recordPayment(uint256 invoiceId, uint256 amount) external;

    /**
     * @notice Settles invoice and distributes profit
     * @dev Transitions to SETTLED, triggers profit distribution
     * @param invoiceId Invoice identifier
     */
    function settleInvoice(uint256 invoiceId) external;

    /**
     * @notice Marks invoice as defaulted
     * @dev Called when payment not received within grace period
     * @param invoiceId Invoice identifier
     */
    function markAsDefaulted(uint256 invoiceId) external;

    /**
     * @notice Calculates current profit for an invoice
     * @dev Formula: (totalAmount - costBasis) if paid, 0 if not
     * @param invoiceId Invoice identifier
     * @return Profit amount realized
     */
    function calculateProfit(uint256 invoiceId) external view returns (uint256);

    /**
     * @notice Redeems tokens for proportional invoice value
     * @dev Allows token holders to exit position
     * @param invoiceId Invoice identifier
     * @param tokenAmount Number of tokens to redeem
     * @return redemptionAmount Amount returned to token holder
     */
    function redeemTokens(
        uint256 invoiceId,
        uint256 tokenAmount
    ) external returns (uint256 redemptionAmount);

    // ============ Query Functions ============

    /**
     * @notice Returns comprehensive invoice details
     * @param invoiceId Invoice identifier
     * @return InvoiceDetails struct with all invoice information
     */
    function getInvoiceDetails(uint256 invoiceId)
        external
        view
        returns (InvoiceDetails memory);

    /**
     * @notice Returns invoice verification information
     * @param invoiceId Invoice identifier
     * @return InvoiceVerification struct with verification details
     */
    function getVerificationInfo(uint256 invoiceId)
        external
        view
        returns (InvoiceVerification memory);

    /**
     * @notice Returns tokenization parameters
     * @param invoiceId Invoice identifier
     * @return TokenizationInfo struct with token details
     */
    function getTokenizationInfo(uint256 invoiceId)
        external
        view
        returns (TokenizationInfo memory);

    /**
     * @notice Returns payment and settlement information
     * @param invoiceId Invoice identifier
     * @return PaymentInfo struct with payment tracking data
     */
    function getPaymentInfo(uint256 invoiceId)
        external
        view
        returns (PaymentInfo memory);

    /**
     * @notice Returns current status of invoice
     * @param invoiceId Invoice identifier
     * @return Current InvoiceStatus enum value
     */
    function getInvoiceStatus(uint256 invoiceId)
        external
        view
        returns (InvoiceStatus);

    /**
     * @notice Checks if invoice is overdue
     * @param invoiceId Invoice identifier
     * @return True if past due date and unpaid, false otherwise
     */
    function isOverdue(uint256 invoiceId) external view returns (bool);

    /**
     * @notice Returns days until payment due
     * @param invoiceId Invoice identifier
     * @return Number of days (can be negative if overdue)
     */
    function getDaysUntilDue(uint256 invoiceId) external view returns (int256);

    /**
     * @notice Returns total number of invoices created
     * @return Invoice count
     */
    function getInvoiceCount() external view returns (uint256);

    /**
     * @notice Returns invoices for a specific seller
     * @param seller Seller address
     * @return Array of invoice IDs
     */
    function getSellerInvoices(address seller)
        external
        view
        returns (uint256[] memory);

    /**
     * @notice Returns invoices for a specific buyer
     * @param buyer Buyer address
     * @return Array of invoice IDs
     */
    function getBuyerInvoices(address buyer)
        external
        view
        returns (uint256[] memory);
}
