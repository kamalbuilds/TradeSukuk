// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IComplianceModule
 * @notice Interface for ERC-3643 compliance modules
 */
interface IComplianceModule {
    /**
     * @notice Checks if a transfer is compliant
     * @param from Sender address (address(0) for minting)
     * @param to Recipient address (address(0) for burning)
     * @param amount Transfer amount
     * @return bool Whether the transfer is compliant
     */
    function canTransfer(
        address from,
        address to,
        uint256 amount
    ) external view returns (bool);

    /**
     * @notice Called after a transfer to update compliance state
     * @param from Sender address
     * @param to Recipient address
     * @param amount Transfer amount
     */
    function transferred(
        address from,
        address to,
        uint256 amount
    ) external;
}
