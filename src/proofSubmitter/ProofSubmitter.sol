// SPDX-FileCopyrightText: 2024 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "./Erc4337Account.sol";
import "./IProofSubmitter.sol";
import "../proofSubmitterFactory/IProofSubmitterFactory.sol";

import "./ProofSubmitterErrors.sol";
import "./ProofSubmitterStructs.sol";

import "../lib/eigenLayer/IEigenPodManager.sol";
import "../lib/eigenLayer/IRewardsCoordinator.sol";
import "../lib/@openzeppelin/contracts/utils/Address.sol";
import "../lib/@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../lib/@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

contract ProofSubmitter is
    Erc4337Account,
    ProofSubmitterErrors,
    ProofSubmitterStructs,
    ERC165,
    IProofSubmitter
{
    IEigenPodManager private immutable i_eigenPodManager;
    IRewardsCoordinator private immutable i_rewardsCoordinator;
    IProofSubmitterFactory private immutable i_factory;

    address private s_owner;
    mapping(address => bool) private s_isOperator;
    mapping(address => mapping(bytes4 => AllowedCalldata))
        private s_allowedFunctionsForContracts;

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
            revert ProofSubmitter__NotFactoryCalled(
                msg.sender,
                address(i_factory)
            );
        }
        _;
    }

    constructor(IProofSubmitterFactory _factory) {
        i_factory = _factory;

        i_eigenPodManager = (block.chainid == 1)
            ? IEigenPodManager(0x91E677b07F7AF907ec9a428aafA9fc14a0d3A338)
            : IEigenPodManager(0x30770d7E3e71112d7A6b7259542D1f680a70e315);

        i_rewardsCoordinator = (block.chainid == 1)
            ? IRewardsCoordinator(0x7750d328b314EfFa365A0402CcfD489B80B0adda)
            : IRewardsCoordinator(0xAcc1fb458a1317E886dB376Fc8141540537E68fE);
    }

    function initialize(address _owner) external onlyFactory {
        if (_owner == address(0)) {
            revert ProofSubmitter__ZeroAddressOwner();
        }

        bool hasPod = i_eigenPodManager.hasPod(_owner);
        if (!hasPod) {
            revert ProofSubmitter__OwnerShouldHaveEigenPod();
        }

        s_owner = _owner;
        emit ProofSubmitter__Initialized(_owner);

        _setInitialRules(_owner);
    }

    function _setInitialRules(address _owner) private {
        address pod = i_eigenPodManager.getPod(_owner);
        _setAllowedFunctionForContract(
            pod,
            IEigenPod.startCheckpoint.selector,
            AllowedCalldata({
                rule: Rule({
                    ruleType: RuleType.AnyCalldata,
                    bytesCount: 0,
                    startIndex: 0
                }),
                allowedBytes: ""
            })
        );
        _setAllowedFunctionForContract(
            pod,
            IEigenPod.verifyWithdrawalCredentials.selector,
            AllowedCalldata({
                rule: Rule({
                    ruleType: RuleType.AnyCalldata,
                    bytesCount: 0,
                    startIndex: 0
                }),
                allowedBytes: ""
            })
        );
        _setAllowedFunctionForContract(
            pod,
            IEigenPod.verifyCheckpointProofs.selector,
            AllowedCalldata({
                rule: Rule({
                    ruleType: RuleType.AnyCalldata,
                    bytesCount: 0,
                    startIndex: 0
                }),
                allowedBytes: ""
            })
        );

        _setAllowedFunctionForContract(
            address(i_rewardsCoordinator),
            IRewardsCoordinator.processClaim.selector,
            AllowedCalldata({
                rule: Rule({
                    ruleType: RuleType.Between,
                    bytesCount: 20,
                    startIndex: 44
                }),
                allowedBytes: abi.encodePacked(_owner)
            })
        );
    }

    function setOperator(address _newOperator) external onlyOperatorOrOwner {
        s_isOperator[_newOperator] = true;

        emit ProofSubmitter__OperatorSet(_newOperator);
    }

    function dismissOperator(address _operator) external onlyOwner {
        s_isOperator[_operator] = false;

        emit ProofSubmitter__OperatorDismissed(_operator);
    }

    function setAllowedFunctionForContract(
        address _contract,
        bytes4 _selector,
        AllowedCalldata calldata _allowedCalldata
    ) external onlyOwner {
        _setAllowedFunctionForContract(_contract, _selector, _allowedCalldata);
    }

    function removeAllowedFunctionForContract(
        address _contract,
        bytes4 _selector
    ) external onlyOwner {
        delete s_allowedFunctionsForContracts[_contract][_selector];

        emit ProofSubmitter__AllowedFunctionForContractRemoved(
            _contract,
            _selector
        );
    }

    /**
     * execute a transaction (called directly from owner, or by entryPoint)
     */
    function execute(
        address _target,
        bytes calldata _data
    ) external onlyEntryPointOrOwner {
        _call(_target, _data);
    }

    /**
     * execute a sequence of transactions
     */
    function executeBatch(
        address[] calldata _targets,
        bytes[] calldata _data
    ) external onlyEntryPointOrOwner {
        if (_targets.length != _data.length) {
            revert ProofSubmitter__WrongArrayLengths(
                _targets.length,
                _data.length
            );
        }

        for (uint256 i = 0; i < _targets.length; i++) {
            _call(_targets[i], _data[i]);
        }
    }

    function _setAllowedFunctionForContract(
        address _contract,
        bytes4 _selector,
        AllowedCalldata memory _allowedCalldata
    ) private {
        s_allowedFunctionsForContracts[_contract][_selector] = _allowedCalldata;

        emit ProofSubmitter__AllowedFunctionForContractSet(
            _contract,
            _selector,
            _allowedCalldata
        );
    }

    function _call(address _target, bytes calldata _data) private {
        bytes4 selector = _getFunctionSelector(_data);
        bool isAllowed = isAllowedCalldata(_target, selector, _data[4:]);

        if (isAllowed) {
            Address.functionCall(_target, _data);
        } else {
            revert ProofSubmitter__NotAllowedToCall(_target, selector);
        }
    }

    /// @notice Returns function selector (first 4 bytes of data)
    /// @param _data calldata (encoded signature + arguments)
    /// @return functionSelector function selector
    function _getFunctionSelector(
        bytes calldata _data
    ) private pure returns (bytes4 functionSelector) {
        if (_data.length < 4) {
            revert ProofSubmitter__DataTooShort();
        }
        return bytes4(_data[:4]);
    }

    function getAllowedCalldata(
        address _target,
        bytes4 _selector
    ) external view returns (AllowedCalldata memory) {
        return s_allowedFunctionsForContracts[_target][_selector];
    }

    function isAllowedCalldata(
        address _target,
        bytes4 _selector,
        bytes calldata _calldataAfterSelector
    ) public view returns (bool) {
        AllowedCalldata
            storage allowedCalldata = s_allowedFunctionsForContracts[_target][
                _selector
            ];
        Rule memory rule = allowedCalldata.rule;

        RuleType ruleType = rule.ruleType;
        uint32 bytesCount = rule.bytesCount;
        uint32 startIndex = rule.startIndex;

        if (ruleType == RuleType.None) {
            return false;
        } else if (ruleType == RuleType.AnyCalldata) {
            return true;
        } else if (ruleType == RuleType.StartsWith) {
            // Ensure the calldata is at least as long as bytesCount
            if (_calldataAfterSelector.length < bytesCount) return false;
            // Compare the beginning of the calldata with the allowed bytes
            return
                keccak256(_calldataAfterSelector[:bytesCount]) ==
                keccak256(allowedCalldata.allowedBytes);
        } else if (ruleType == RuleType.EndsWith) {
            // Ensure the calldata is at least as long as bytesCount
            if (_calldataAfterSelector.length < bytesCount) return false;
            // Compare the end of the calldata with the allowed bytes
            return
                keccak256(
                    _calldataAfterSelector[_calldataAfterSelector.length -
                        bytesCount:]
                ) == keccak256(allowedCalldata.allowedBytes);
        } else if (ruleType == RuleType.Between) {
            // Ensure the calldata is at least as long as the range defined by startIndex and bytesCount
            if (_calldataAfterSelector.length < startIndex + bytesCount)
                return false;
            // Compare the specified range in the calldata with the allowed bytes
            return
                keccak256(
                    _calldataAfterSelector[startIndex:startIndex + bytesCount]
                ) == keccak256(allowedCalldata.allowedBytes);
        }

        // Default to false if none of the conditions are met
        return false;
    }

    function owner() public view override(Erc4337Account) returns (address) {
        return s_owner;
    }

    function isOperator(
        address _address
    ) public view override(Erc4337Account) returns (bool) {
        return s_isOperator[_address];
    }

    function factory() public view override returns (address) {
        return address(i_factory);
    }

    /// @inheritdoc ERC165
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IProofSubmitter).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
