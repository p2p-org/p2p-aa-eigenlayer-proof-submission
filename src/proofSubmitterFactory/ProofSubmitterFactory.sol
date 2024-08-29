// SPDX-FileCopyrightText: 2024 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../proofSubmitter/ProofSubmitter.sol";
import "./IProofSubmitterFactory.sol";
import "../lib/@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../lib/@openzeppelin/contracts/proxy/Clones.sol";

contract ProofSubmitterFactory is ERC165, IProofSubmitterFactory {
    /// @notice Singleton ERC-4337 entryPoint 0.6.0
    address payable constant entryPoint = payable(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);

    ProofSubmitter public immutable i_referenceProofSubmitter;

    constructor() {
        i_referenceProofSubmitter = new ProofSubmitter();
    }

    function createProofSubmitter() external payable returns (ProofSubmitter proofSubmitter) {
        address proofSubmitterAddress = predictProofSubmitterAddress(msg.sender);
        uint256 codeSize = proofSubmitterAddress.code.length;
        if (codeSize > 0) {
            return ProofSubmitter(payable(proofSubmitterAddress));
        }

        proofSubmitter = ProofSubmitter(payable(Clones.cloneDeterministic(
            address(i_referenceProofSubmitter),
            bytes32(uint256(uint160(msg.sender)))
        )));

        proofSubmitter.initialize(msg.sender);

        IEntryPointStakeManager(entryPoint).depositTo{value: msg.value}(proofSubmitterAddress);
    }

    function predictProofSubmitterAddress(address _owner) public view returns (address) {
        return Clones.predictDeterministicAddress(
            address(i_referenceProofSubmitter),
            bytes32(uint256(uint160(_owner)))
        );
    }

    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IProofSubmitterFactory).interfaceId || super.supportsInterface(interfaceId);
    }
}
