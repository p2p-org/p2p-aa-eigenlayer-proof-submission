// SPDX-FileCopyrightText: 2024 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;
import "../lib/@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "./ProofSubmitterStructs.sol";

/// @dev External interface of ProofSubmitter declared to support ERC165 detection.
interface IProofSubmitter is IERC165 {

    /// @notice TODO
    event ProofSubmitter__Initialized(address _owner);

    event ProofSubmitter__OperatorSet(address _newOperator);

    event ProofSubmitter__OperatorDismissed(address _operator);

    event ProofSubmitter__AllowedFunctionForContractSet(
        address indexed _contract,
        bytes4 indexed _selector,
        ProofSubmitterStructs.AllowedCalldata _allowedCalldata
    );

    event ProofSubmitter__AllowedFunctionForContractRemoved(
        address _contract,
        bytes4 _selector
    );

    /// @notice Set owner address.
    /// @dev Could not be in the constructor since it is different for different owners.
    /// @param _owner owner address
    function initialize(address _owner) external;

    /// @notice Returns the factory address
    /// @return address factory address
    function factory() external view returns (address);
}
