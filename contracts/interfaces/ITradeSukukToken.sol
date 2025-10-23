// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IERC3643.sol";

/**
 * @title ITradeSukukToken
 * @notice Interface for TradeSukuk security tokens with Shariah compliance
 * @dev Extends ERC-3643 with Islamic finance specific features and profit distribution
 * @custom:security-contact security@tradesukuk.com
 */
interface ITradeSukukToken is IERC3643 {

    // ============ Structs ============

    /**
     * @notice Shariah compliance metadata for the token
     * @param certificateHash IPFS hash of Shariah compliance certificate
     * @param certifyingScholar Address of the scholar who certified compliance
     * @param certificationDate Timestamp of certification
     * @param expiryDate Timestamp when certification expires
     * @param isValid Current validity status
     */
    struct ShariahCertificate {
        bytes32 certificateHash;
        address certifyingScholar;
        uint256 certificationDate;
        uint256 expiryDate;
        bool isValid;
    }

    /**
     * @notice Profit distribution details
     * @param totalProfit Total profit amount to distribute
     * @param distributionDate Timestamp of distribution
     * @param profitPerToken Profit amount per token unit
     * @param distributed Whether distribution has been executed
     */
    struct ProfitDistribution {
        uint256 totalProfit;
        uint256 distributionDate;
        uint256 profitPerToken;
        bool distributed;
    }

    /**
     * @notice Token holder information
     * @param balance Current token balance
     * @param frozenBalance Frozen/restricted tokens
     * @param lastClaimDate Last profit claim timestamp
     * @param accumulatedProfit Unclaimed profit amount
     */
    struct TokenHolderInfo {
        uint256 balance;
        uint256 frozenBalance;
        uint256 lastClaimDate;
        uint256 accumulatedProfit;
    }

    // ============ Events ============

    /**
     * @notice Emitted when Shariah compliance certificate is updated
     * @param certificateHash IPFS hash of the new certificate
     * @param scholar Address of the certifying scholar
     * @param expiryDate Expiration date of the certificate
     */
    event ShariahCertificateUpdated(
        bytes32 indexed certificateHash,
        address indexed scholar,
        uint256 expiryDate
    );

    /**
     * @notice Emitted when profit is distributed to token holders
     * @param distributionId Unique identifier for the distribution
     * @param totalProfit Total profit amount distributed
     * @param profitPerToken Profit per token unit
     * @param timestamp Distribution execution time
     */
    event ProfitDistributed(
        uint256 indexed distributionId,
        uint256 totalProfit,
        uint256 profitPerToken,
        uint256 timestamp
    );

    /**
     * @notice Emitted when a token holder claims their profit
     * @param holder Address of the token holder
     * @param amount Profit amount claimed
     * @param timestamp Claim execution time
     */
    event ProfitClaimed(
        address indexed holder,
        uint256 amount,
        uint256 timestamp
    );

    /**
     * @notice Emitted when token metadata is updated
     * @param key Metadata key
     * @param value New metadata value
     */
    event MetadataUpdated(string key, string value);

    /**
     * @notice Emitted when underlying asset details are updated
     * @param assetType Type of underlying asset
     * @param assetIdentifier Unique identifier for the asset
     * @param valuationAmount Current valuation in base currency
     */
    event UnderlyingAssetUpdated(
        string assetType,
        string assetIdentifier,
        uint256 valuationAmount
    );

    // ============ Shariah Compliance ============

    /**
     * @notice Returns the current Shariah compliance certificate
     * @dev Certificate must be valid and not expired for token operations
     * @return ShariahCertificate struct with all certificate details
     */
    function getShariahCertificate() external view returns (ShariahCertificate memory);

    /**
     * @notice Updates the Shariah compliance certificate
     * @dev Only callable by authorized Shariah board members
     * @param certificateHash IPFS hash of the new certificate document
     * @param scholar Address of the certifying scholar
     * @param expiryDate Timestamp when the certificate expires
     */
    function updateShariahCertificate(
        bytes32 certificateHash,
        address scholar,
        uint256 expiryDate
    ) external;

    /**
     * @notice Checks if the token is currently Shariah compliant
     * @dev Verifies certificate validity and expiration date
     * @return True if compliant, false otherwise
     */
    function isShariahCompliant() external view returns (bool);

    /**
     * @notice Revokes Shariah compliance certification
     * @dev Only callable by Shariah board, freezes all transfers
     * @param reason Explanation for revocation
     */
    function revokeShariahCompliance(string calldata reason) external;

    // ============ Profit Distribution ============

    /**
     * @notice Initiates a profit distribution to all token holders
     * @dev Calculates pro-rata distribution based on token holdings
     * @param totalProfit Total profit amount to distribute (in base currency)
     * @return distributionId Unique identifier for this distribution
     */
    function distributeProfit(uint256 totalProfit) external returns (uint256 distributionId);

    /**
     * @notice Returns profit distribution details for a specific distribution
     * @param distributionId Unique identifier of the distribution
     * @return ProfitDistribution struct with distribution details
     */
    function getProfitDistribution(uint256 distributionId)
        external
        view
        returns (ProfitDistribution memory);

    /**
     * @notice Calculates claimable profit for a specific token holder
     * @param holder Address of the token holder
     * @return Claimable profit amount in base currency
     */
    function getClaimableProfit(address holder) external view returns (uint256);

    /**
     * @notice Allows token holder to claim accumulated profit
     * @dev Transfers profit amount to holder's address
     * @return amount Amount of profit claimed
     */
    function claimProfit() external returns (uint256 amount);

    /**
     * @notice Returns total number of profit distributions
     * @return Total count of distributions executed
     */
    function getDistributionCount() external view returns (uint256);

    // ============ Token Holder Information ============

    /**
     * @notice Returns comprehensive information about a token holder
     * @param holder Address of the token holder
     * @return TokenHolderInfo struct with holder details
     */
    function getTokenHolderInfo(address holder)
        external
        view
        returns (TokenHolderInfo memory);

    /**
     * @notice Returns the total number of verified token holders
     * @return Count of unique addresses holding tokens
     */
    function getHolderCount() external view returns (uint256);

    /**
     * @notice Returns token holder address at a specific index
     * @dev Used for iteration over all holders
     * @param index Position in the holders array
     * @return Address of the token holder
     */
    function getHolderAt(uint256 index) external view returns (address);

    // ============ Metadata Management ============

    /**
     * @notice Sets token metadata (name, symbol, description, etc.)
     * @dev Only callable by token administrator
     * @param key Metadata identifier
     * @param value Metadata content
     */
    function setMetadata(string calldata key, string calldata value) external;

    /**
     * @notice Retrieves token metadata by key
     * @param key Metadata identifier
     * @return Metadata value as string
     */
    function getMetadata(string calldata key) external view returns (string memory);

    /**
     * @notice Updates underlying asset information
     * @dev Links token to real-world asset (invoice, commodity, etc.)
     * @param assetType Category of the asset (e.g., "invoice", "commodity")
     * @param assetIdentifier Unique identifier (e.g., invoice number, asset ID)
     * @param valuationAmount Current market value in base currency
     */
    function setUnderlyingAsset(
        string calldata assetType,
        string calldata assetIdentifier,
        uint256 valuationAmount
    ) external;

    /**
     * @notice Returns underlying asset details
     * @return assetType Type of the underlying asset
     * @return assetIdentifier Unique identifier of the asset
     * @return valuationAmount Current valuation amount
     */
    function getUnderlyingAsset()
        external
        view
        returns (
            string memory assetType,
            string memory assetIdentifier,
            uint256 valuationAmount
        );

    // ============ Advanced Features ============

    /**
     * @notice Pauses all token transfers
     * @dev Emergency function, only callable by admin
     */
    function pause() external;

    /**
     * @notice Resumes token transfers after pause
     * @dev Only callable by admin
     */
    function unpause() external;

    /**
     * @notice Returns whether token transfers are currently paused
     * @return True if paused, false otherwise
     */
    function isPaused() external view returns (bool);

    /**
     * @notice Burns tokens and returns proportional underlying asset value
     * @dev Implements redemption mechanism for maturity or early exit
     * @param amount Number of tokens to redeem
     * @return redemptionValue Value returned to token holder
     */
    function redeem(uint256 amount) external returns (uint256 redemptionValue);

    /**
     * @notice Calculates redemption value for a given token amount
     * @param amount Number of tokens to check
     * @return Estimated redemption value in base currency
     */
    function getRedemptionValue(uint256 amount) external view returns (uint256);
}
