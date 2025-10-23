// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IERC3643
 * @notice Core interface for ERC-3643 compliant security tokens
 * @dev Extends ERC20 with identity and compliance requirements for tokenized securities
 * @custom:security-contact security@tradesukuk.com
 */
interface IERC3643 is IERC20 {

    // ============ Events ============

    /**
     * @notice Emitted when tokens are forcefully transferred by an authorized agent
     * @param from Address from which tokens were taken
     * @param to Address to which tokens were sent
     * @param amount Number of tokens transferred
     * @param reason Human-readable justification for forced transfer
     */
    event ForcedTransfer(
        address indexed from,
        address indexed to,
        uint256 amount,
        string reason
    );

    /**
     * @notice Emitted when tokens are frozen for a specific address
     * @param account Address whose tokens were frozen
     * @param amount Number of tokens frozen
     */
    event TokensFrozen(address indexed account, uint256 amount);

    /**
     * @notice Emitted when frozen tokens are unfrozen
     * @param account Address whose tokens were unfrozen
     * @param amount Number of tokens unfrozen
     */
    event TokensUnfrozen(address indexed account, uint256 amount);

    /**
     * @notice Emitted when an identity is registered for an address
     * @param account Address for which identity was registered
     * @param identityRegistry Address of the identity registry contract
     */
    event IdentityRegistered(
        address indexed account,
        address indexed identityRegistry
    );

    /**
     * @notice Emitted when the compliance contract is updated
     * @param oldCompliance Previous compliance contract address
     * @param newCompliance New compliance contract address
     */
    event ComplianceUpdated(
        address indexed oldCompliance,
        address indexed newCompliance
    );

    // ============ Identity Management ============

    /**
     * @notice Returns the identity registry contract address
     * @dev The identity registry manages investor identities and verification
     * @return Address of the identity registry contract
     */
    function identityRegistry() external view returns (address);

    /**
     * @notice Returns the compliance contract address
     * @dev The compliance contract enforces transfer restrictions and regulations
     * @return Address of the compliance module contract
     */
    function compliance() external view returns (address);

    /**
     * @notice Checks if an address has a verified identity
     * @param account Address to check for verified identity
     * @return True if the address has a verified identity, false otherwise
     */
    function isVerified(address account) external view returns (bool);

    // ============ Transfer Restrictions ============

    /**
     * @notice Checks if a transfer is compliant with all regulations
     * @dev Must validate identity, compliance rules, and token restrictions
     * @param from Address sending tokens
     * @param to Address receiving tokens
     * @param amount Number of tokens to transfer
     * @return True if transfer is allowed, false otherwise
     */
    function canTransfer(
        address from,
        address to,
        uint256 amount
    ) external view returns (bool);

    /**
     * @notice Forces a transfer of tokens by an authorized agent
     * @dev Only callable by addresses with AGENT_ROLE
     * @param from Address from which to take tokens
     * @param to Address to which to send tokens
     * @param amount Number of tokens to transfer
     * @param reason Justification for the forced transfer
     */
    function forcedTransfer(
        address from,
        address to,
        uint256 amount,
        string calldata reason
    ) external;

    // ============ Token Freezing ============

    /**
     * @notice Freezes a specific amount of tokens for an address
     * @dev Frozen tokens cannot be transferred until unfrozen
     * @param account Address whose tokens to freeze
     * @param amount Number of tokens to freeze
     */
    function freezeTokens(address account, uint256 amount) external;

    /**
     * @notice Unfreezes previously frozen tokens
     * @param account Address whose tokens to unfreeze
     * @param amount Number of tokens to unfreeze
     */
    function unfreezeTokens(address account, uint256 amount) external;

    /**
     * @notice Returns the amount of frozen tokens for an address
     * @param account Address to check for frozen tokens
     * @return Number of frozen tokens
     */
    function getFrozenTokens(address account) external view returns (uint256);

    // ============ Compliance Updates ============

    /**
     * @notice Sets a new compliance contract
     * @dev Only callable by contract owner/admin
     * @param complianceContract Address of the new compliance contract
     */
    function setCompliance(address complianceContract) external;

    /**
     * @notice Sets a new identity registry contract
     * @dev Only callable by contract owner/admin
     * @param identityRegistryContract Address of the new identity registry
     */
    function setIdentityRegistry(address identityRegistryContract) external;

    // ============ Batch Operations ============

    /**
     * @notice Batch mints tokens to multiple addresses
     * @dev Only callable by addresses with MINTER_ROLE
     * @param accounts Array of addresses to receive tokens
     * @param amounts Array of token amounts corresponding to each address
     */
    function batchMint(
        address[] calldata accounts,
        uint256[] calldata amounts
    ) external;

    /**
     * @notice Batch burns tokens from multiple addresses
     * @dev Only callable by addresses with BURNER_ROLE
     * @param accounts Array of addresses from which to burn tokens
     * @param amounts Array of token amounts corresponding to each address
     */
    function batchBurn(
        address[] calldata accounts,
        uint256[] calldata amounts
    ) external;
}
