// SPDX-FileCopyrightText: 2024 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

contract ProofSubmitterErrors {
    /// @notice data length should be at least 4 byte to be a function signature
    error ProofSubmitter__DataTooShort();

    /// @notice The caller is not allowed to call the function
    /// @param _target The target address
    /// @param _selector The selector of the function
    error ProofSubmitter__NotAllowedToCall(address _target, bytes4 _selector);

    /// @notice The caller is neither an operator nor the owner
    /// @param _caller The address of the caller
    error ProofSubmitter__CallerNeitherOperatorNorOwner(address _caller);

    /// @notice The caller is neither an entry point nor the owner
    /// @param _caller The address of the caller
    error ProofSubmitter__CallerNeitherEntryPointNorOwner(address _caller);

    /// @notice The caller is not the factory
    /// @param _caller The address of the caller
    /// @param _factory The address of the factory
    error ProofSubmitter__NotFactoryCalled(address _caller, address _factory);

    /// @notice The owner address should not be zero
    error ProofSubmitter__ZeroAddressOwner();

    /// @notice The owner should have a valid EigenPod
    error ProofSubmitter__OwnerShouldHaveEigenPod();

    /// @notice The lengths of the targets and data arrays should be the same
    /// @param _targetsLength The length of the targets array
    /// @param _dataLength The length of the data array
    error ProofSubmitter__WrongArrayLengths(
        uint256 _targetsLength,
        uint256 _dataLength
    );
}
