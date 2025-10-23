// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IIdentityRegistry.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockIdentityRegistry
 * @notice Mock implementation of identity registry for testing
 */
contract MockIdentityRegistry is IIdentityRegistry, Ownable {
    struct Identity {
        address identityContract;
        bytes2 country;
        bool isVerified;
    }

    mapping(address => Identity) private identities;

    constructor(address initialOwner) Ownable(initialOwner) {}

    function isVerified(address account) external view override returns (bool) {
        return identities[account].isVerified;
    }

    function getIdentity(address account)
        external
        view
        override
        returns (address identity, bytes2 country)
    {
        Identity memory id = identities[account];
        return (id.identityContract, id.country);
    }

    function registerIdentity(
        address account,
        address identity,
        bytes2 country
    ) external override onlyOwner {
        identities[account] = Identity({
            identityContract: identity,
            country: country,
            isVerified: true
        });
    }

    function deleteIdentity(address account) external override onlyOwner {
        delete identities[account];
    }

    // Helper function for testing
    function batchRegisterIdentities(
        address[] calldata accounts,
        bytes2 country
    ) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            identities[accounts[i]] = Identity({
                identityContract: accounts[i],
                country: country,
                isVerified: true
            });
        }
    }
}
