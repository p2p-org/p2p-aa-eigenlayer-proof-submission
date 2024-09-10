// SPDX-FileCopyrightText: 2024 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../proofSubmitter/ProofSubmitter.sol";
import "./IProofSubmitterFactory.sol";
import "../lib/@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../lib/@openzeppelin/contracts/proxy/Clones.sol";

/// @title ProofSubmitterFactory
/// @notice Factory for creating ProofSubmitter contract instances
contract ProofSubmitterFactory is ERC165, IProofSubmitterFactory {
    /// @notice Singleton ERC-4337 entryPoint 0.6.0
    address payable public constant entryPoint =
        payable(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);

    /// @notice Reference ProofSubmitter contract
    ProofSubmitter public immutable i_referenceProofSubmitter;

    constructor() {
        i_referenceProofSubmitter = new ProofSubmitter(this);
    }

    /// @notice Creates a new ProofSubmitter contract instance
    /// @return proofSubmitter The new ProofSubmitter contract instance
    function createProofSubmitter()
        external
        payable
        returns (ProofSubmitter proofSubmitter)
    {
        address proofSubmitterAddress = predictProofSubmitterAddress(
            msg.sender
        );
        uint256 codeSize = proofSubmitterAddress.code.length;
        if (codeSize > 0) {
            return ProofSubmitter(payable(proofSubmitterAddress));
        }

        proofSubmitter = ProofSubmitter(
            payable(
                Clones.cloneDeterministic(
                    address(i_referenceProofSubmitter),
                    bytes32(uint256(uint160(msg.sender)))
                )
            )
        );

        proofSubmitter.initialize(msg.sender);

        IEntryPointStakeManager(entryPoint).depositTo{value: msg.value}(
            proofSubmitterAddress
        );
    }

    /// @notice Predicts the address of a ProofSubmitter contract instance
    /// @param _owner The owner of the ProofSubmitter contract instance
    /// @return The address of the ProofSubmitter contract instance
    function predictProofSubmitterAddress(
        address _owner
    ) public view returns (address) {
        return
            Clones.predictDeterministicAddress(
                address(i_referenceProofSubmitter),
                bytes32(uint256(uint160(_owner)))
            );
    }

    /// @notice Returns the address of the reference ProofSubmitter contract
    /// @return The address of the reference ProofSubmitter contract
    function getReferenceProofSubmitter() external view returns (address) {
        return address(i_referenceProofSubmitter);
    }

    /// @inheritdoc ERC165
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IProofSubmitterFactory).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
