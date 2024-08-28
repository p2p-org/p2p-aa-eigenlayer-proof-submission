// SPDX-FileCopyrightText: 2024 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "./@openzeppelin/contracts/proxy/Clones.sol";
import "./proofSubmitter/ProofSubmitter.sol";
import "./IProofSubmitterFactory.sol";

contract ProofSubmitterFactory is IProofSubmitterFactory {
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
            i_referenceProofSubmitter,
            bytes32(msg.sender)
        )));

        proofSubmitter.initialize(msg.sender);

        IEntryPointStakeManager(entryPoint).depositTo{value: msg.value}(proofSubmitterAddress);
    }

    function predictProofSubmitterAddress(address owner) public view returns (address) {
        return Clones.predictDeterministicAddress(
            i_referenceProofSubmitter,
            bytes32(owner)
        );
    }
}
