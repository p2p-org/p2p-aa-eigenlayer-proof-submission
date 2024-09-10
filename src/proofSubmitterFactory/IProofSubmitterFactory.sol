// SPDX-FileCopyrightText: 2024 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;
import "../lib/@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "../proofSubmitter/ProofSubmitter.sol";

/// @dev External interface of ProofSubmitterFactory declared to support ERC165 detection.
interface IProofSubmitterFactory is IERC165 {
    /// @notice Creates a new ProofSubmitter contract instance
    /// @return proofSubmitter The new ProofSubmitter contract instance
    function createProofSubmitter()
        external
        payable
        returns (ProofSubmitter proofSubmitter);

    /// @notice Predicts the address of a ProofSubmitter contract instance
    /// @param _owner The owner of the ProofSubmitter contract instance
    /// @return The address of the ProofSubmitter contract instance
    function predictProofSubmitterAddress(
        address _owner
    ) external view returns (address);

    /// @notice Returns the address of the reference ProofSubmitter contract
    /// @return The address of the reference ProofSubmitter contract
    function getReferenceProofSubmitter() external view returns (address);
}
