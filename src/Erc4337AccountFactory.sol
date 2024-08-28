// SPDX-FileCopyrightText: 2024 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "./@openzeppelin/contracts/proxy/Clones.sol";
import "./Erc4337Account.sol";

contract Erc4337AccountFactory {
    /// @notice Singleton ERC-4337 entryPoint 0.6.0
    address payable constant entryPoint = payable(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);

    Erc4337Account public immutable i_referenceErc4337Account;

    constructor() {
        i_referenceErc4337Account = new Erc4337Account();
    }

    function createAccount() external payable returns (Erc4337Account account) {
        address accountAddress = predictAccountAddress(msg.sender);
        uint256 codeSize = accountAddress.code.length;
        if (codeSize > 0) {
            return Erc4337Account(payable(accountAddress));
        }

        account = Erc4337Account(payable(Clones.cloneDeterministic(
            i_referenceErc4337Account,
            bytes32(msg.sender)
        )));

        account.initialize(msg.sender);

        IEntryPointStakeManager(entryPoint).depositTo{value: msg.value}(accountAddress);
    }

    function predictAccountAddress(address owner) public view returns (address) {
        return Clones.predictDeterministicAddress(
            i_referenceErc4337Account,
            bytes32(owner)
        );
    }
}
