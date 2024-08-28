// SPDX-FileCopyrightText: 2024 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "./Erc4337Account.sol";
import "./IProofSubmitter.sol";
import "../proofSubmitterFactory/IProofSubmitterFactory.sol";
import "../lib/eigenLayer/IEigenPodManager.sol";
import "../lib/@openzeppelin/contracts/utils/Address.sol";


contract ProofSubmitter is Erc4337Account, IProofSubmitter {
    IEigenPodManager private immutable i_eigenPodManager;
    IProofSubmitterFactory private immutable i_factory;

    address private s_owner;

    mapping (address => bool) private s_isOperator;

    /// @notice If caller is any account other than the operator or the owner, revert
    modifier onlyOperatorOrOwner() {
        if (!isOperator(msg.sender) && msg.sender != owner()) {
            revert ProofSubmitter__CallerNeitherOperatorNorOwner(msg.sender);
        }
        _;
    }

    /// @notice If caller is any account other than the EntryPoint or the owner, revert
    modifier onlyEntryPointOrOwner() {
        if (msg.sender != entryPoint && msg.sender != owner()) {
            revert ProofSubmitter__CallerNeitherEntryPointNorOwner(msg.sender);
        }
        _;
    }

    /// @notice If caller not factory, revert
    modifier onlyFactory() {
        if (msg.sender != address(i_factory)) {
            revert ProofSubmitter__NotFactoryCalled(msg.sender, i_factory);
        }
        _;
    }

    constructor(address _factory, IEigenPodManager _eigenPodManager) {
        i_eigenPodManager = _eigenPodManager;
    }

    /// @inheritdoc
    function initialize(address _owner) external onlyFactory {
        if (_owner == address(0)) {
            revert();
        }

        s_owner = _owner;

        emit ProofSubmitter__Initialized(_owner);

        bool hasPod = i_eigenPodManager.hasPod(_owner);
        if (!hasPod) {
            revert();
        }
    }

    function setOperator(address _newOperator) external onlyOperatorOrOwner {
        s_isOperator[_newOperator] = true;

        emit ProofSubmitter__OperatorSet(_newOperator);
    }

    function dismissOperator(address _operator) external onlyOwner {
        s_isOperator[_operator] = false;

        emit ProofSubmitter__OperatorDismissed(_operator);
    }

    /**
    * execute a transaction (called directly from owner, or by entryPoint)
    */
    function execute(address target, bytes calldata data) external onlyEntryPointOrOwner {
        Address.functionCall(target, data);
    }

    /**
     * execute a sequence of transactions
     */
    function executeBatch(address[] calldata targets, bytes[] calldata data) external onlyEntryPointOrOwner {
        if (targets.length != data.length) {
            revert ProofSubmitter__WrongArrayLengths(targets.length, data.length);
        }

        for (uint256 i = 0; i < targets.length; i++) {
            Address.functionCall(targets[i], data[i]);
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

    function owner() public view override(Erc4337Account) returns (address) {
        return s_owner;
    }

    function isOperator(address _address) public view returns (bool) {
        return s_isOperator[_address];
    }
}
