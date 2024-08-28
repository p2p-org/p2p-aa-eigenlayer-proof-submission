// SPDX-FileCopyrightText: 2024 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../erc4337/IAccount.sol";
import "../erc4337/IEntryPointStakeManager.sol";
import "../erc4337/UserOperation.sol";
import "./eigenLayer/IEigenPodManager.sol";

/// @notice passed address should be a valid ERC-4337 entryPoint
/// @param _passedAddress passed address
error Erc4337Account__NotEntryPoint(address _passedAddress);

/// @notice data length should be at least 4 byte to be a function signature
error Erc4337Account__DataTooShort();

/// @notice only account owner is allowed to withdraw from EntryPoint
error Erc4337Account__NotAllowedToWithdrawFromEntryPoint();

/// @title ERC-4337 smart wallet account
abstract contract Erc4337Account is IAccount {
    using ECDSA for bytes32;

    /// @notice Singleton ERC-4337 entryPoint 0.6.0
    address payable constant entryPoint = payable(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);

    IEigenPodManager private i_eigenPodManager;

    address private s_owner;

    constructor(IEigenPodManager _eigenPodManager) {
        i_eigenPodManager = _eigenPodManager;
    }

    /// @inheritdoc
    function initialize(
        address _owner
    ) external onlyFactory {
        if (_owner == address(0)) {
            revert();
        }

        s_owner = _owner;

        emit Erc4337Account__Initialized(_owner);

        bool hasPod = i_eigenPodManager.hasPod(_owner);
        if (!hasPod) {
            revert();
        }
    }

    /// @inheritdoc IAccount
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external override returns (uint256 validationData) {
        if (msg.sender != entryPoint) {
            revert Erc4337Account__NotEntryPoint(msg.sender);
        }

        validationData = _validateSignature(userOp, userOpHash);
        _payPrefund(missingAccountFunds);
    }

    /// @notice Withdraw this contract's balance from EntryPoint back to this contract
    function withdrawFromEntryPoint() external {
        if (msg.sender != owner()) {
            revert Erc4337Account__NotAllowedToWithdrawFromEntryPoint();
        }

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
            signer == operator() || signer == owner()
        ) {
            validationData = 0;
        } else {
            validationData = 1;
        }
    }

    /// @notice Returns function selector (first 4 bytes of data)
    /// @param _data calldata (encoded signature + arguments)
    /// @return functionSelector function selector
    function _getFunctionSelector(bytes calldata _data) private pure returns (bytes4 functionSelector) {
        if (_data.length < 4) {
            revert Erc4337Account__DataTooShort();
        }
        return bytes4(_data[:4]);
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

    function _call(address target, bytes memory data) internal {
        (bool success, bytes memory result) = target.call(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    function owner() public view returns (address) {
        return s_owner;
    }

    function operator() public view virtual returns (address);
}
