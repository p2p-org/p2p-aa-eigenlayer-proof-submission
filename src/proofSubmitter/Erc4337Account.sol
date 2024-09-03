// SPDX-FileCopyrightText: 2024 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../lib/erc4337/UserOperation.sol";
import "../lib/erc4337/IAccount.sol";
import "../lib/@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../lib/erc4337/IEntryPointStakeManager.sol";

/// @notice passed address should be the owner
/// @param _passedAddress passed address
error Erc4337Account__NotOwner(address _passedAddress, address _owner);

/// @notice passed address should be a valid ERC-4337 entryPoint
/// @param _passedAddress passed address
error Erc4337Account__NotEntryPoint(address _passedAddress);


/// @title ERC-4337 smart wallet account
abstract contract Erc4337Account is IAccount {
    using ECDSA for bytes32;

    /// @notice Singleton ERC-4337 entryPoint 0.6.0
    address payable constant entryPoint = payable(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);

    /// @notice If caller not factory, revert
    modifier onlyEntryPoint() {
        if (msg.sender != entryPoint) {
            revert Erc4337Account__NotEntryPoint(msg.sender);
        }
        _;
    }

    /// @notice If caller not owner, revert
    modifier onlyOwner() {
        if (msg.sender != owner()) {
            revert Erc4337Account__NotOwner(msg.sender, owner());
        }
        _;
    }

    /// @inheritdoc IAccount
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    )
    external
    onlyEntryPoint
    override
    returns (uint256 validationData) {
        validationData = _validateSignature(userOp, userOpHash);
        _payPrefund(missingAccountFunds);
    }

    /// @notice Withdraw this contract's balance from EntryPoint back to this contract
    function withdrawFromEntryPoint() external onlyOwner {
        uint256 balance = IEntryPointStakeManager(entryPoint).balanceOf(address(this));
        IEntryPointStakeManager(entryPoint).withdrawTo(payable(address(this)), balance);
    }

    /// @notice Validates the signature of a user operation.
    /// @param _userOp the operation that is about to be executed.
    /// @param _userOpHash hash of the user's request data. can be used as the basis for signature.
    /// @return validationData 0 for valid signature, 1 to mark signature failure
    function _validateSignature(
        UserOperation calldata _userOp,
        bytes32 _userOpHash
    ) private view returns (uint256 validationData)
    {
        bytes32 hash = _userOpHash.toEthSignedMessageHash();
        address signer = hash.recover(_userOp.signature);

        if (
            isOperator(signer) || signer == owner()
        ) {
            validationData = 0;
        } else {
            validationData = 1;
        }
    }

    /// @notice sends to the entrypoint (msg.sender) the missing funds for this transaction.
    /// @param _missingAccountFunds the minimum value this method should send the entrypoint.
    /// this value MAY be zero, in case there is enough deposit, or the userOp has a paymaster.
    function _payPrefund(uint256 _missingAccountFunds) private {
        if (_missingAccountFunds != 0) {
            (bool success, ) = payable(msg.sender).call{ value: _missingAccountFunds, gas: type(uint256).max }("");
            (success);
            //ignore failure (its EntryPoint's job to verify, not account.)
        }
    }

    function owner() public view virtual returns (address);

    function getBalance() external view returns (uint256) {
        return IEntryPointStakeManager(entryPoint).balanceOf(address(this));
    }

    function isOperator(address _address) public view virtual returns (bool);
}
