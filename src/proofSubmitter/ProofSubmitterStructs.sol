// SPDX-FileCopyrightText: 2024 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

contract ProofSubmitterStructs {
    enum RuleType {
        None,
        AnyCalldata,
        StartsWith,
        EndsWith,
        Between
    }

    struct Rule {
        RuleType ruleType;
        uint32 bytesCount;
        uint32 startIndex;
    }

    struct AllowedCalldata {
        Rule rule;
        bytes allowedBytes;
    }
}
