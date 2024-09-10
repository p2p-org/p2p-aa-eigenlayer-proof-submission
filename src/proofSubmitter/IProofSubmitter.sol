// SPDX-FileCopyrightText: 2024 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;
import "../lib/@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "./ProofSubmitterStructs.sol";

/// @dev External interface of ProofSubmitter declared to support ERC165 detection.
interface IProofSubmitter is IERC165 {
    /// @notice Emitted when the ProofSubmitter contract is initialized
    /// @param _owner The address of the owner set during initialization
    event ProofSubmitter__Initialized(address _owner);

    /// @notice Emitted when a new operator is set
    /// @param _newOperator The address of the new operator
    event ProofSubmitter__OperatorSet(address _newOperator);

    /// @notice Emitted when an operator is dismissed
    /// @param _operator The address of the operator dismissed
    event ProofSubmitter__OperatorDismissed(address _operator);

    /// @notice Emitted when a new allowed function for a contract is set
    /// @param _contract The address of the contract
    /// @param _selector The selector of the function
    /// @param _allowedCalldata The allowed calldata for the function
    event ProofSubmitter__AllowedFunctionForContractSet(
        address indexed _contract,
        bytes4 indexed _selector,
        ProofSubmitterStructs.AllowedCalldata _allowedCalldata
    );

    /// @notice Emitted when an allowed function for a contract is removed
    /// @param _contract The address of the contract
    /// @param _selector The selector of the function
    event ProofSubmitter__AllowedFunctionForContractRemoved(
        address _contract,
        bytes4 _selector
    );

    /// @notice Set owner address.
    /// @dev Could not be in the constructor since it is different for different owners.
    /// @param _owner owner address
    function initialize(address _owner) external;

    /// @notice Set operator for the ProofSubmitter instance
    /// @param _newOperator The new operator address
    function setOperator(address _newOperator) external;

    /// @notice Dismiss operator for the ProofSubmitter instance
    /// @param _operator The operator address to dismiss
    function dismissOperator(address _operator) external;

    /// @notice Set allowed calldata for a specific contract and selector
    /// @param _contract The contract address
    /// @param _selector The selector of the function
    /// @param _allowedCalldata The allowed calldata for the function
    function setAllowedFunctionForContract(
        address _contract,
        bytes4 _selector,
        ProofSubmitterStructs.AllowedCalldata calldata _allowedCalldata
    ) external;

    /// @notice Remove allowed calldata for a specific contract and selector
    /// @param _contract The contract address
    /// @param _selector The selector of the function
    function removeAllowedFunctionForContract(
        address _contract,
        bytes4 _selector
    ) external;

    /// @notice Execute a transaction (called directly from owner, or by entryPoint)
    /// @param _target The target address of the transaction
    /// @param _data The calldata of the transaction
    function execute(address _target, bytes calldata _data) external;

    /// @notice Execute a sequence of transactions
    /// @param _targets The target addresses of the transactions
    /// @param _data The calldata of the transactions
    function executeBatch(
        address[] calldata _targets,
        bytes[] calldata _data
    ) external;

    /// @notice Get allowed calldata for a specific contract and selector
    /// @param _target The contract address
    /// @param _selector The selector of the function
    /// @return allowedCalldata The allowed calldata for the function
    function getAllowedCalldata(
        address _target,
        bytes4 _selector
    ) external view returns (ProofSubmitterStructs.AllowedCalldata memory);

    /// @notice Check if calldata is allowed for a specific contract and selector
    /// @param _target The contract address
    /// @param _selector The selector of the function
    /// @param _calldataAfterSelector The calldata after the selector
    /// @return isAllowed true if calldata is allowed, false otherwise
    function isAllowedCalldata(
        address _target,
        bytes4 _selector,
        bytes calldata _calldataAfterSelector
    ) external view returns (bool);

    /// @notice Returns the factory address
    /// @return address factory address
    function factory() external view returns (address);
}
