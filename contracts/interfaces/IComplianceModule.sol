// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IComplianceModule
 * @notice Interface for comprehensive compliance verification including KYC/AML and Shariah compliance
 * @dev Integrates with Polygon ID for decentralized identity verification
 * @custom:security-contact security@tradesukuk.com
 */
interface IComplianceModule {

    // ============ Enums ============

    /**
     * @notice Identity verification level
     */
    enum VerificationLevel {
        NONE,               // No verification
        BASIC,              // Basic KYC (name, email)
        STANDARD,           // Standard KYC (government ID)
        ENHANCED,           // Enhanced due diligence
        INSTITUTIONAL       // Institutional verification
    }

    /**
     * @notice Investor accreditation status
     */
    enum AccreditationStatus {
        NONE,               // Not accredited
        RETAIL,             // Retail investor
        ACCREDITED,         // Accredited investor
        QUALIFIED,          // Qualified institutional buyer
        PROFESSIONAL        // Professional investor
    }

    /**
     * @notice Jurisdiction classification
     */
    enum JurisdictionType {
        UNRESTRICTED,       // No restrictions
        RESTRICTED,         // Some limitations apply
        SANCTIONED,         // Sanctioned jurisdiction
        PROHIBITED          // Completely prohibited
    }

    // ============ Structs ============

    /**
     * @notice KYC/AML verification data
     * @param isVerified Overall verification status
     * @param verificationLevel Level of verification completed
     * @param verifiedAt Timestamp of verification
     * @param expiryDate Expiration date of verification
     * @param verifier Address of verifying authority
     * @param documentHash IPFS hash of verification documents
     * @param polygonIdClaim Polygon ID claim identifier
     */
    struct KYCData {
        bool isVerified;
        VerificationLevel verificationLevel;
        uint256 verifiedAt;
        uint256 expiryDate;
        address verifier;
        bytes32 documentHash;
        uint256 polygonIdClaim;
    }

    /**
     * @notice Investor accreditation information
     * @param status Accreditation classification
     * @param jurisdiction Country/region code
     * @param accreditedAt Timestamp of accreditation
     * @param expiryDate Expiration of accreditation
     * @param verifyingAuthority Address that granted accreditation
     * @param proofHash IPFS hash of accreditation proof
     */
    struct AccreditationInfo {
        AccreditationStatus status;
        string jurisdiction;
        uint256 accreditedAt;
        uint256 expiryDate;
        address verifyingAuthority;
        bytes32 proofHash;
    }

    /**
     * @notice Transfer restriction rules
     * @param maxHolders Maximum number of token holders
     * @param minHoldingPeriod Minimum holding period in seconds
     * @param maxTokensPerAddress Maximum tokens per address
     * @param allowedJurisdictions List of permitted jurisdiction codes
     * @param blockedAddresses List of sanctioned/blocked addresses
     * @param requireAccreditation Whether accreditation is required
     */
    struct TransferRestrictions {
        uint256 maxHolders;
        uint256 minHoldingPeriod;
        uint256 maxTokensPerAddress;
        string[] allowedJurisdictions;
        address[] blockedAddresses;
        bool requireAccreditation;
    }

    /**
     * @notice Shariah compliance verification
     * @param isCompliant Current compliance status
     * @param certifyingScholar Address of Shariah scholar
     * @param certificateHash IPFS hash of compliance certificate
     * @param certifiedAt Certification timestamp
     * @param reviewDate Next review date
     * @param complianceNotes Additional compliance information
     */
    struct ShariahCompliance {
        bool isCompliant;
        address certifyingScholar;
        bytes32 certificateHash;
        uint256 certifiedAt;
        uint256 reviewDate;
        string complianceNotes;
    }

    // ============ Events ============

    /**
     * @notice Emitted when KYC verification is completed
     * @param account Address that was verified
     * @param level Verification level achieved
     * @param verifier Address that performed verification
     */
    event KYCVerified(
        address indexed account,
        VerificationLevel level,
        address indexed verifier
    );

    /**
     * @notice Emitted when KYC verification is revoked
     * @param account Address whose verification was revoked
     * @param reason Explanation for revocation
     */
    event KYCRevoked(
        address indexed account,
        string reason
    );

    /**
     * @notice Emitted when accreditation status is updated
     * @param account Address whose accreditation changed
     * @param status New accreditation status
     * @param jurisdiction Jurisdiction code
     */
    event AccreditationUpdated(
        address indexed account,
        AccreditationStatus status,
        string jurisdiction
    );

    /**
     * @notice Emitted when Polygon ID claim is verified
     * @param account Address associated with claim
     * @param claimId Polygon ID claim identifier
     * @param claimType Type of claim verified
     */
    event PolygonIDVerified(
        address indexed account,
        uint256 claimId,
        string claimType
    );

    /**
     * @notice Emitted when transfer restriction rules are updated
     * @param token Token contract address
     * @param timestamp Update time
     */
    event TransferRestrictionsUpdated(
        address indexed token,
        uint256 timestamp
    );

    /**
     * @notice Emitted when Shariah compliance is certified
     * @param token Token contract address
     * @param scholar Certifying scholar address
     * @param certificateHash IPFS hash of certificate
     */
    event ShariahCertified(
        address indexed token,
        address indexed scholar,
        bytes32 certificateHash
    );

    /**
     * @notice Emitted when address is blocked
     * @param account Blocked address
     * @param reason Reason for blocking
     */
    event AddressBlocked(
        address indexed account,
        string reason
    );

    /**
     * @notice Emitted when address is unblocked
     * @param account Unblocked address
     */
    event AddressUnblocked(
        address indexed account
    );

    // ============ KYC/AML Functions ============

    /**
     * @notice Verifies KYC for an address
     * @dev Only callable by authorized verifiers
     * @param account Address to verify
     * @param level Verification level to assign
     * @param expiryDate Expiration date of verification
     * @param documentHash IPFS hash of KYC documents
     */
    function verifyKYC(
        address account,
        VerificationLevel level,
        uint256 expiryDate,
        bytes32 documentHash
    ) external;

    /**
     * @notice Revokes KYC verification
     * @param account Address whose verification to revoke
     * @param reason Explanation for revocation
     */
    function revokeKYC(address account, string calldata reason) external;

    /**
     * @notice Checks if address has valid KYC
     * @param account Address to check
     * @return True if KYC is valid and not expired, false otherwise
     */
    function isKYCVerified(address account) external view returns (bool);

    /**
     * @notice Returns complete KYC data for an address
     * @param account Address to query
     * @return KYCData struct with verification details
     */
    function getKYCData(address account) external view returns (KYCData memory);

    /**
     * @notice Checks if address passes AML screening
     * @param account Address to screen
     * @return True if address is not sanctioned or blocked, false otherwise
     */
    function passesAML(address account) external view returns (bool);

    // ============ Polygon ID Integration ============

    /**
     * @notice Verifies Polygon ID claim for an address
     * @dev Integrates with Polygon ID protocol for decentralized identity
     * @param account Address associated with claim
     * @param claimId Polygon ID claim identifier
     * @param claimType Type of claim (e.g., "KYC", "Accreditation")
     * @param proofData ZK proof data for verification
     */
    function verifyPolygonIDClaim(
        address account,
        uint256 claimId,
        string calldata claimType,
        bytes calldata proofData
    ) external;

    /**
     * @notice Checks if address has valid Polygon ID claim
     * @param account Address to check
     * @param claimType Type of claim to verify
     * @return True if valid claim exists, false otherwise
     */
    function hasValidPolygonID(
        address account,
        string calldata claimType
    ) external view returns (bool);

    /**
     * @notice Returns Polygon ID claim ID for an address
     * @param account Address to query
     * @return Claim identifier (0 if none)
     */
    function getPolygonIDClaim(address account) external view returns (uint256);

    // ============ Accreditation Management ============

    /**
     * @notice Sets accreditation status for an investor
     * @param account Investor address
     * @param status Accreditation classification
     * @param jurisdiction Country/region code
     * @param expiryDate Expiration date
     * @param proofHash IPFS hash of accreditation proof
     */
    function setAccreditation(
        address account,
        AccreditationStatus status,
        string calldata jurisdiction,
        uint256 expiryDate,
        bytes32 proofHash
    ) external;

    /**
     * @notice Checks if address is accredited investor
     * @param account Address to check
     * @return True if accredited and not expired, false otherwise
     */
    function isAccredited(address account) external view returns (bool);

    /**
     * @notice Returns accreditation information
     * @param account Address to query
     * @return AccreditationInfo struct with details
     */
    function getAccreditationInfo(address account)
        external
        view
        returns (AccreditationInfo memory);

    // ============ Jurisdiction & Restrictions ============

    /**
     * @notice Checks if jurisdiction is allowed
     * @param jurisdictionCode Country/region code
     * @return True if jurisdiction is permitted, false otherwise
     */
    function isJurisdictionAllowed(string calldata jurisdictionCode)
        external
        view
        returns (bool);

    /**
     * @notice Adds allowed jurisdiction
     * @param token Token contract address
     * @param jurisdictionCode Country/region code to allow
     */
    function addAllowedJurisdiction(
        address token,
        string calldata jurisdictionCode
    ) external;

    /**
     * @notice Removes allowed jurisdiction
     * @param token Token contract address
     * @param jurisdictionCode Country/region code to remove
     */
    function removeAllowedJurisdiction(
        address token,
        string calldata jurisdictionCode
    ) external;

    /**
     * @notice Blocks an address from all transactions
     * @param account Address to block
     * @param reason Explanation for blocking
     */
    function blockAddress(address account, string calldata reason) external;

    /**
     * @notice Unblocks a previously blocked address
     * @param account Address to unblock
     */
    function unblockAddress(address account) external;

    /**
     * @notice Checks if address is blocked
     * @param account Address to check
     * @return True if blocked, false otherwise
     */
    function isBlocked(address account) external view returns (bool);

    // ============ Transfer Compliance Checks ============

    /**
     * @notice Validates if a transfer is compliant
     * @dev Comprehensive check including KYC, accreditation, jurisdiction, restrictions
     * @param token Token contract address
     * @param from Sender address
     * @param to Recipient address
     * @param amount Transfer amount
     * @return True if transfer is compliant, false otherwise
     */
    function canTransfer(
        address token,
        address from,
        address to,
        uint256 amount
    ) external view returns (bool);

    /**
     * @notice Returns detailed compliance check results
     * @param token Token contract address
     * @param from Sender address
     * @param to Recipient address
     * @param amount Transfer amount
     * @return kycPassed Whether KYC checks passed
     * @return accreditationPassed Whether accreditation checks passed
     * @return jurisdictionPassed Whether jurisdiction checks passed
     * @return restrictionsPassed Whether transfer restrictions passed
     * @return reason Failure reason if any check failed
     */
    function getTransferComplianceDetails(
        address token,
        address from,
        address to,
        uint256 amount
    ) external view returns (
        bool kycPassed,
        bool accreditationPassed,
        bool jurisdictionPassed,
        bool restrictionsPassed,
        string memory reason
    );

    /**
     * @notice Sets transfer restriction rules for a token
     * @param token Token contract address
     * @param restrictions TransferRestrictions struct with rules
     */
    function setTransferRestrictions(
        address token,
        TransferRestrictions calldata restrictions
    ) external;

    /**
     * @notice Returns transfer restrictions for a token
     * @param token Token contract address
     * @return TransferRestrictions struct with current rules
     */
    function getTransferRestrictions(address token)
        external
        view
        returns (TransferRestrictions memory);

    // ============ Shariah Compliance ============

    /**
     * @notice Certifies Shariah compliance for a token
     * @param token Token contract address
     * @param certificateHash IPFS hash of Shariah certificate
     * @param reviewDate Next scheduled review date
     * @param complianceNotes Additional compliance information
     */
    function certifyShariahCompliance(
        address token,
        bytes32 certificateHash,
        uint256 reviewDate,
        string calldata complianceNotes
    ) external;

    /**
     * @notice Revokes Shariah compliance certification
     * @param token Token contract address
     * @param reason Explanation for revocation
     */
    function revokeShariahCompliance(
        address token,
        string calldata reason
    ) external;

    /**
     * @notice Checks if token is Shariah compliant
     * @param token Token contract address
     * @return True if compliant and certificate valid, false otherwise
     */
    function isShariahCompliant(address token) external view returns (bool);

    /**
     * @notice Returns Shariah compliance details
     * @param token Token contract address
     * @return ShariahCompliance struct with certification details
     */
    function getShariahCompliance(address token)
        external
        view
        returns (ShariahCompliance memory);

    // ============ Administrative Functions ============

    /**
     * @notice Adds authorized KYC verifier
     * @param verifier Address to authorize
     */
    function addVerifier(address verifier) external;

    /**
     * @notice Removes KYC verifier authorization
     * @param verifier Address to deauthorize
     */
    function removeVerifier(address verifier) external;

    /**
     * @notice Checks if address is authorized verifier
     * @param verifier Address to check
     * @return True if authorized, false otherwise
     */
    function isVerifier(address verifier) external view returns (bool);

    /**
     * @notice Adds authorized Shariah scholar
     * @param scholar Address to authorize
     */
    function addShariahScholar(address scholar) external;

    /**
     * @notice Removes Shariah scholar authorization
     * @param scholar Address to deauthorize
     */
    function removeShariahScholar(address scholar) external;

    /**
     * @notice Checks if address is authorized Shariah scholar
     * @param scholar Address to check
     * @return True if authorized, false otherwise
     */
    function isShariahScholar(address scholar) external view returns (bool);
}
