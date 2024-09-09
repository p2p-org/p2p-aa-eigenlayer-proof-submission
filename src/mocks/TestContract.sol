// SPDX-FileCopyrightText: 2024 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

/// @dev Mock for testing. NOT to be deployed on mainnet!!!
contract TestContract {
    uint256 public value;

    function setValue(uint256 _value) external {
        value = _value;
    }
}
