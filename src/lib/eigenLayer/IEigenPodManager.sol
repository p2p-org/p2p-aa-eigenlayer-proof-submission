// SPDX-FileCopyrightText: 2024 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IEigenPodManager {
    function hasPod(address podOwner) external view returns (bool);
}
