// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract ProofSubmitterErrors {
    /// @notice data length should be at least 4 byte to be a function signature
    error ProofSubmitter__DataTooShort();

    error ProofSubmitter__NotAllowedToCall(
        address _target,
        bytes4 _selector
    );

    error ProofSubmitter__CallerNeitherOperatorNorOwner(address _caller);

    error ProofSubmitter__CallerNeitherEntryPointNorOwner(address _caller);

    error ProofSubmitter__NotFactoryCalled(
        address _caller,
        address _factory
    );

    error ProofSubmitter__ZeroAddressOwner();

    error ProofSubmitter__OwnerShouldHaveEigenPod();

    error ProofSubmitter__WrongArrayLengths(
        uint256 _targetsLength,
        uint256 _dataLength
    );
}
