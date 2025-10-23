// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IIdentityRegistry
 * @notice Interface for on-chain identity registry (Polygon ID integration)
 */
interface IIdentityRegistry {
    /**
     * @notice Checks if an address has verified identity
     * @param account Address to check
     * @return bool Whether the address is verified
     */
    function isVerified(address account) external view returns (bool);

    /**
     * @notice Gets identity details for an address
     * @param account Address to query
     * @return identity Identity contract address
     * @return country Country code (ISO 3166-1 alpha-2)
     */
    function getIdentity(address account)
        external
        view
        returns (address identity, bytes2 country);

    /**
     * @notice Registers identity for an address
     * @param account Address to register
     * @param identity Identity contract address
     * @param country Country code
     */
    function registerIdentity(
        address account,
        address identity,
        bytes2 country
    ) external;

    /**
     * @notice Removes identity registration
     * @param account Address to deregister
     */
    function deleteIdentity(address account) external;
}
