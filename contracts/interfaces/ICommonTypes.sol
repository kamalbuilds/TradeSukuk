// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ICommonTypes
 * @notice Shared data structures and types used across TradeSukuk contracts
 * @dev Provides common enums, structs, and constants to avoid duplication
 * @custom:security-contact security@tradesukuk.com
 */
interface ICommonTypes {

    // ============ Common Enums ============

    /**
     * @notice Currency types supported by the platform
     */
    enum Currency {
        USD,                // US Dollar
        EUR,                // Euro
        GBP,                // British Pound
        AED,                // UAE Dirham
        SAR,                // Saudi Riyal
        MYR,                // Malaysian Ringgit
        USDC,               // USD Coin stablecoin
        USDT                // Tether stablecoin
    }

    /**
     * @notice Asset classes for tokenization
     */
    enum AssetClass {
        INVOICE,            // Trade invoice
        COMMODITY,          // Physical commodities
        REAL_ESTATE,        // Property assets
        EQUITY,             // Business equity
        RECEIVABLES,        // Accounts receivable
        SUPPLY_CHAIN,       // Supply chain finance
        INFRASTRUCTURE,     // Infrastructure projects
        MURABAHA,           // Murabaha contracts
        IJARA,              // Lease/rental contracts
        MUSHARAKA           // Partnership/joint venture
    }

    /**
     * @notice Risk rating categories
     */
    enum RiskRating {
        AAA,                // Highest credit quality
        AA,                 // High credit quality
        A,                  // Strong credit quality
        BBB,                // Good credit quality
        BB,                 // Speculative
        B,                  // Highly speculative
        CCC,                // Substantial risk
        CC,                 // Very high risk
        C,                  // Extremely high risk
        D                   // Default
    }

    // ============ Common Structs ============

    /**
     * @notice Address with role and metadata
     * @param addr Ethereum address
     * @param role Role identifier
     * @param name Human-readable name
     * @param isActive Whether address is currently active
     * @param addedDate Timestamp when address was added
     */
    struct AddressWithRole {
        address addr;
        bytes32 role;
        string name;
        bool isActive;
        uint256 addedDate;
    }

    /**
     * @notice Document reference (typically IPFS hash)
     * @param documentHash IPFS hash or URI
     * @param documentType Type/category of document
     * @param uploadedBy Address that uploaded document
     * @param uploadedDate Timestamp of upload
     * @param isVerified Whether document has been verified
     * @param verifiedBy Address that verified document
     */
    struct DocumentReference {
        bytes32 documentHash;
        string documentType;
        address uploadedBy;
        uint256 uploadedDate;
        bool isVerified;
        address verifiedBy;
    }

    /**
     * @notice Financial amount with currency
     * @param amount Numeric amount
     * @param currency Currency denomination
     * @param decimals Number of decimal places
     */
    struct MonetaryAmount {
        uint256 amount;
        Currency currency;
        uint8 decimals;
    }

    /**
     * @notice Time period definition
     * @param startDate Period start timestamp
     * @param endDate Period end timestamp
     * @param duration Duration in seconds
     */
    struct TimePeriod {
        uint256 startDate;
        uint256 endDate;
        uint256 duration;
    }

    /**
     * @notice Geographic location
     * @param country ISO country code
     * @param region State/province
     * @param city City name
     * @param coordinates Latitude/longitude (encoded)
     */
    struct Location {
        string country;
        string region;
        string city;
        bytes32 coordinates;
    }

    /**
     * @notice Party information (buyer, seller, investor, etc.)
     * @param partyAddress Ethereum address
     * @param partyType Type of party
     * @param legalName Legal entity name
     * @param jurisdiction Legal jurisdiction
     * @param taxId Tax identification number (encrypted)
     * @param isVerified KYC verification status
     * @param riskRating Assigned risk rating
     */
    struct Party {
        address partyAddress;
        string partyType;
        string legalName;
        string jurisdiction;
        bytes32 taxId;
        bool isVerified;
        RiskRating riskRating;
    }

    /**
     * @notice Audit trail entry
     * @param actor Address that performed action
     * @param action Description of action
     * @param timestamp When action occurred
     * @param dataHash Hash of related data
     * @param metadata Additional information
     */
    struct AuditEntry {
        address actor;
        string action;
        uint256 timestamp;
        bytes32 dataHash;
        string metadata;
    }

    /**
     * @notice Fee structure
     * @param feeType Type of fee
     * @param feeAmount Amount or percentage
     * @param feeBasisPoints Fee in basis points (if percentage)
     * @param feeRecipient Address to receive fee
     * @param feeMinimum Minimum fee amount
     * @param feeMaximum Maximum fee amount
     */
    struct FeeStructure {
        string feeType;
        uint256 feeAmount;
        uint256 feeBasisPoints;
        address feeRecipient;
        uint256 feeMinimum;
        uint256 feeMaximum;
    }

    /**
     * @notice Token snapshot for point-in-time balances
     * @param snapshotId Unique snapshot identifier
     * @param snapshotDate Timestamp of snapshot
     * @param totalSupply Total token supply at snapshot
     * @param holderCount Number of holders at snapshot
     * @param purpose Reason for snapshot
     */
    struct TokenSnapshot {
        uint256 snapshotId;
        uint256 snapshotDate;
        uint256 totalSupply;
        uint256 holderCount;
        string purpose;
    }

    /**
     * @notice Voting record for governance
     * @param proposalId Proposal identifier
     * @param voter Address that voted
     * @param support Whether vote is in favor
     * @param votingPower Number of votes cast
     * @param voteDate Timestamp of vote
     * @param reason Optional voting rationale
     */
    struct VoteRecord {
        uint256 proposalId;
        address voter;
        bool support;
        uint256 votingPower;
        uint256 voteDate;
        string reason;
    }

    // ============ Common Constants ============

    /**
     * @notice Maximum basis points (100%)
     */
    function MAX_BASIS_POINTS() external pure returns (uint256);

    /**
     * @notice Precision for decimal calculations
     */
    function PRECISION() external pure returns (uint256);

    /**
     * @notice Seconds in a day
     */
    function SECONDS_PER_DAY() external pure returns (uint256);

    /**
     * @notice Seconds in a year (365 days)
     */
    function SECONDS_PER_YEAR() external pure returns (uint256);

    /**
     * @notice Default grace period in seconds (30 days)
     */
    function DEFAULT_GRACE_PERIOD() external pure returns (uint256);

    /**
     * @notice Minimum holding period in seconds (24 hours)
     */
    function MIN_HOLDING_PERIOD() external pure returns (uint256);

    // ============ Utility Functions ============

    /**
     * @notice Converts basis points to percentage
     * @param basisPoints Value in basis points
     * @return Percentage value (0-100)
     */
    function basisPointsToPercentage(uint256 basisPoints)
        external
        pure
        returns (uint256);

    /**
     * @notice Converts percentage to basis points
     * @param percentage Percentage value (0-100)
     * @return Value in basis points
     */
    function percentageToBasisPoints(uint256 percentage)
        external
        pure
        returns (uint256);

    /**
     * @notice Calculates percentage of amount
     * @param amount Base amount
     * @param basisPoints Percentage in basis points
     * @return Calculated percentage amount
     */
    function calculatePercentage(uint256 amount, uint256 basisPoints)
        external
        pure
        returns (uint256);

    /**
     * @notice Checks if date is in the past
     * @param timestamp Date to check
     * @return True if date has passed, false otherwise
     */
    function isPastDate(uint256 timestamp) external view returns (bool);

    /**
     * @notice Checks if date is in the future
     * @param timestamp Date to check
     * @return True if date is upcoming, false otherwise
     */
    function isFutureDate(uint256 timestamp) external view returns (bool);

    /**
     * @notice Calculates days between two dates
     * @param startDate Start timestamp
     * @param endDate End timestamp
     * @return Number of days (can be negative)
     */
    function daysBetween(uint256 startDate, uint256 endDate)
        external
        pure
        returns (int256);

    /**
     * @notice Adds days to a timestamp
     * @param timestamp Base timestamp
     * @param days Number of days to add
     * @return New timestamp
     */
    function addDays(uint256 timestamp, uint256 days)
        external
        pure
        returns (uint256);

    /**
     * @notice Validates IPFS hash format
     * @param hash Hash to validate
     * @return True if valid IPFS hash format, false otherwise
     */
    function isValidIPFSHash(bytes32 hash) external pure returns (bool);

    /**
     * @notice Validates Ethereum address
     * @param addr Address to validate
     * @return True if valid non-zero address, false otherwise
     */
    function isValidAddress(address addr) external pure returns (bool);
}
