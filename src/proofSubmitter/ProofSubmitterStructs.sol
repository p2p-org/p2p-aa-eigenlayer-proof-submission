// SPDX-FileCopyrightText: 2024 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

/// @title ProofSubmitterStructs
/// @notice Structs used in the ProofSubmitter contract
contract ProofSubmitterStructs {
    /// @notice Enum representing the type of rule for allowed calldata
    enum RuleType {
        None,
        AnyCalldata,
        StartsWith,
        EndsWith,
        Between
    }

    /// @notice Struct representing a rule for allowed calldata
    /// @param ruleType The type of rule
    /// @param bytesCount The number of bytes to check
    /// @param startIndex The start index of the bytes to check
    struct Rule {
        RuleType ruleType;
        uint32 bytesCount;
        uint32 startIndex;
    }

    /// @notice Struct representing allowed calldata
    /// @param rule The rule for allowed calldata
    /// @param allowedBytes The allowed bytes
    struct AllowedCalldata {
        Rule rule;
        bytes allowedBytes;
    }
}
