// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract ProofSubmitterStructs {
    enum RuleType {
        NonAllowed,
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
