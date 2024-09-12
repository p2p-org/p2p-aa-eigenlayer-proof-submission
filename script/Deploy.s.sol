// SPDX-FileCopyrightText: 2024 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import {Script} from "forge-std/Script.sol";
import "../src/proofSubmitterFactory/ProofSubmitterFactory.sol";
import "../src/proofSubmitter/ProofSubmitter.sol";

contract Deploy is Script {
    function run()
        external
        returns (ProofSubmitterFactory factory, ProofSubmitter proofSubmitter)
    {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerKey);
        factory = new ProofSubmitterFactory();
        proofSubmitter = factory.createProofSubmitter();
        vm.stopBroadcast();

        return (factory, proofSubmitter);
    }
}
