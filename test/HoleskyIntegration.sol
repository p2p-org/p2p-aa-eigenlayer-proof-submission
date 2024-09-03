// SPDX-FileCopyrightText: 2024 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/console2.sol";
import "../src/proofSubmitterFactory/ProofSubmitterFactory.sol";
import "../src/proofSubmitter/ProofSubmitterErrors.sol";
import "../src/mocks/IEigenPodManagerMock.sol";

contract HoleskyIntegration is Test {
    IEigenPodManagerMock private constant eigenPodManager = IEigenPodManagerMock(0x30770d7E3e71112d7A6b7259542D1f680a70e315);
    IRewardsCoordinator private constant rewardsCoordinator = IRewardsCoordinator(0xAcc1fb458a1317E886dB376Fc8141540537E68fE);

    ProofSubmitterFactory private factory;

    address private clientAddress;
    uint256 private clientPrivateKey;
    address private serviceAddress;
    uint256 private servicePrivateKey;

    function setUp() public {
        vm.createSelectFork("holesky", 2255110);

        (clientAddress, clientPrivateKey) = makeAddrAndKey("client");
        (serviceAddress, servicePrivateKey) = makeAddrAndKey("service");

        vm.deal(clientAddress, 1000 ether);

        factory = new ProofSubmitterFactory();
    }

    function test_ProofSubmitterGettingBalance() external {
        uint256 deposited = 10 ether;

        vm.startPrank(clientAddress);

        vm.expectRevert(ProofSubmitterErrors.ProofSubmitter__OwnerShouldHaveEigenPod.selector);
        ProofSubmitter proofSubmitter = factory.createProofSubmitter{value: deposited}();

        eigenPodManager.createPod();
        proofSubmitter = factory.createProofSubmitter{value: deposited}();

        vm.stopPrank();

        uint256 actualBalance = proofSubmitter.getBalance();
        assertEq(deposited, actualBalance);
    }

    function test_WithdrawFromEntryPoint() external {
        uint256 deposited = 10 ether;

        vm.startPrank(clientAddress);

        eigenPodManager.createPod();
        ProofSubmitter proofSubmitter = factory.createProofSubmitter{value: deposited}();

        uint256 actualBalance = proofSubmitter.getBalance();
        assertEq(deposited, actualBalance);

        uint256 clientBalanceBeforeWithdraw = clientAddress.balance;
        proofSubmitter.withdrawFromEntryPoint();
        uint256 clientBalanceAfterWithdraw = clientAddress.balance;

        assertEq(clientBalanceAfterWithdraw - clientBalanceBeforeWithdraw, deposited);

        vm.stopPrank();
    }
}
