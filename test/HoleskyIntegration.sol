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
import "../src/mocks/IEigenPodMock.sol";
import "../src/proofSubmitter/ProofSubmitterStructs.sol";
import "../src/lib/erc4337/UserOperation.sol";
import "../src/mocks/erc4337/IEntryPoint.sol";

contract HoleskyIntegration is Test {
    IEigenPodManagerMock private constant eigenPodManager =
        IEigenPodManagerMock(0x30770d7E3e71112d7A6b7259542D1f680a70e315);
    IRewardsCoordinator private constant rewardsCoordinator =
        IRewardsCoordinator(0xAcc1fb458a1317E886dB376Fc8141540537E68fE);
    IEntryPoint private constant entryPoint =
        IEntryPoint(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);

    ProofSubmitterFactory private factory;

    address private clientAddress;
    uint256 private clientPrivateKey;
    address private serviceAddress;
    uint256 private servicePrivateKey;
    address private nobody;

    function setUp() public {
        vm.createSelectFork("holesky", 2255110);

        (clientAddress, clientPrivateKey) = makeAddrAndKey("client");
        (serviceAddress, servicePrivateKey) = makeAddrAndKey("service");
        nobody = makeAddr("nobody");

        vm.deal(clientAddress, 1000 ether);

        factory = new ProofSubmitterFactory();
    }

    function test_ProofSubmitterGettingBalance() external {
        uint256 deposited = 10 ether;

        vm.startPrank(clientAddress);

        vm.expectRevert(
            ProofSubmitterErrors
                .ProofSubmitter__OwnerShouldHaveEigenPod
                .selector
        );
        ProofSubmitter proofSubmitter = factory.createProofSubmitter{
            value: deposited
        }();

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
        ProofSubmitter proofSubmitter = factory.createProofSubmitter{
            value: deposited
        }();

        uint256 actualBalance = proofSubmitter.getBalance();
        assertEq(deposited, actualBalance);

        uint256 clientBalanceBeforeWithdraw = clientAddress.balance;
        proofSubmitter.withdrawFromEntryPoint();
        uint256 clientBalanceAfterWithdraw = clientAddress.balance;

        assertEq(
            clientBalanceAfterWithdraw - clientBalanceBeforeWithdraw,
            deposited
        );

        vm.stopPrank();
    }

    function test_ProofSubmitterExecuteOnPodFromOwner() external {
        uint256 deposited = 10 ether;

        vm.startPrank(clientAddress);

        address pod = eigenPodManager.createPod();
        ProofSubmitter proofSubmitter = factory.createProofSubmitter{
            value: deposited
        }();
        proofSubmitter.setOperator(serviceAddress);
        IEigenPodMock(pod).setProofSubmitter(address(proofSubmitter));

        vm.expectRevert("EigenPod.getParentBlockRoot: timestamp out of range");
        proofSubmitter.execute(pod, verifyWithdrawalCredentialsCalldata);

        proofSubmitter.execute(pod, startCheckpointCalldata);

        vm.expectRevert(
            "EigenPod.verifyCheckpointProofs: must have active checkpoint to perform checkpoint proof"
        );
        proofSubmitter.execute(pod, verifyCheckpointProofsCalldata);

        vm.stopPrank();
    }

    function test_ProofSubmitterExecuteOnRewardsCoordinatorFromOwner()
        external
    {
        uint256 deposited = 10 ether;

        vm.startPrank(clientAddress);

        address pod = eigenPodManager.createPod();
        ProofSubmitter proofSubmitter = factory.createProofSubmitter{
            value: deposited
        }();
        proofSubmitter.setOperator(serviceAddress);
        IEigenPodMock(pod).setProofSubmitter(address(proofSubmitter));

        vm.expectRevert(stdError.indexOOBError);
        proofSubmitter.execute(
            address(rewardsCoordinator),
            processClaimCalldata
        );

        vm.stopPrank();
    }

    function _generateUnsignedUserOperation(
        address _sender,
        bytes memory _callData
    ) private view returns(UserOperation memory) {
        uint256 nonce = 0;
        return UserOperation({
            sender: _sender,
            nonce: nonce,
            initCode: "",
            callData: _callData,
            callGasLimit: 1000000,
            verificationGasLimit: 1000000,
            preVerificationGas: 1000000,
            maxFeePerGas: 1 gwei,
            maxPriorityFeePerGas: 1 gwei,
            paymasterAndData: "",
            signature: ""
        });
    }

    function test_ProofSubmitterExecuteOnRewardsCoordinatorFromServiceViaEntryPoint()
    external
    {
        uint256 deposited = 10 ether;

        vm.startPrank(clientAddress);

        eigenPodManager.createPod();
        ProofSubmitter proofSubmitter = factory.createProofSubmitter{
                value: deposited
            }();
        proofSubmitter.setOperator(serviceAddress);

        vm.stopPrank();

        bytes memory executeCallData = abi.encodeWithSelector(
            ProofSubmitter.execute.selector,
            address(rewardsCoordinator),
            processClaimCalldata
        );
        vm.expectCall(
            address(proofSubmitter),
            executeCallData
        );
        vm.expectCall(
            address(rewardsCoordinator),
            processClaimCalldata
        );
        _executeUserOperation(
            address(proofSubmitter),
            servicePrivateKey,
            executeCallData
        );
    }

    function _executeUserOperation(
        address _smartAccountAddress,
        uint256 _signerPrivateKey,
        bytes memory _callData
    ) private {
        vm.startPrank(nobody);

        UserOperation memory userOp = _generateUnsignedUserOperation(
            _smartAccountAddress,
            _callData
        );

        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        bytes32 digest = ECDSA.toEthSignedMessageHash(userOpHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            _signerPrivateKey,
            digest
        );
        userOp.signature = abi.encodePacked(r, s, v);

        // Create an array with a single user operation
        UserOperation[] memory userOps = new UserOperation[](1);
        userOps[0] = userOp;

        // Call handleOps on the EntryPoint
        entryPoint.handleOps(userOps, payable(nobody));

        vm.stopPrank();
    }

    bytes private constant processClaimCalldata =
        hex"3ccc861d0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000D5e069BC58dedb2a3A348995ee753Eef0274004F000000000000000000000000000000000000000000000000000000000000004b00000000000000000000000000000000000000000000000000000000000192350000000000000000000000000000000000000000000000000000000000000100000000000000000000000000D5e069BC58dedb2a3A348995ee753Eef0274004F95f0093489d51d9e2f039ed2fce75382c01a534a81d210f9dac82c7e27aea19f0000000000000000000000000000000000000000000000000000000000000340000000000000000000000000000000000000000000000000000000000000038000000000000000000000000000000000000000000000000000000000000003e000000000000000000000000000000000000000000000000000000000000002206bd8b8552455002951ab0141d76f12d24ce2c75a916c88d55bad21e2573e30d81ff53126be651b2ee23ac0978db0ef57249f7024fb2975b67d33832b92cf25fd7b04224e2508aa18c9a5e141fe1b7bab61541c90282dd771d4c4efc651f202671563a379cd034e64b2138864dacd05f1b998b6a1c18f8cb6527d095b991581fb595adee1ce007161da3247b0fcc1b312d1c57537320517c837c68e3b89d233cd0bb2251248851a8cbc96be2de63cde11ba6986fc0e43bf73fc8eea7401cb254d73c6c73c96e04e8a79491b6eccfecbac37be3cc3c0444fd858aab9b1169eb73735487409170623edc2b4714fe99ad5291f584eea5b9073ef7d2ef22606d75164835bce9ca91fb56c57318fecc85403388fe1d2e034f25ce84e719aa45cad462f9058dd5a949125136139812a13d649923e924df607f4c17211cbf4f046288ac7b0ede366758f6abf153ed2c8d3580de3144ec6777ce6281ba50f1a3eda93611deaea3a4ceef182b0fe8cbfb7c58b2f84ba7f234db49a8007d345445247d63594061228864e78b39c7de495c2953ceee805987b2d278c72b87e7ca9029e514f37ba20cf2d697283f958e4a32a88c15ecb5c2476aa7e6f26e8da1e924c763c582ae44946784deda2609277e536824a70e81e515aa6e84328cce37e519abeac06689964710330b3195b2aaa356608d28666e4c3b3f97a54addece11f91b81ce1f0c5d5dab4d4bb07541c125acd5ee0a8a77170289b87a9e4b99e699f6b28843d2e7000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000deeeee2b48c121e6728ed95c860e29617784993200000000000000000000000000000000000000000000005264d3061ea97744f0";
    bytes private constant startCheckpointCalldata =
        hex"88676cad0000000000000000000000000000000000000000000000000000000000000000";
    bytes private constant verifyCheckpointProofsCalldata =
        hex"f074ba62000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000001a0b0fa07ecc6f23173ab5d25db3fe3f350dd0952690a0c50b4553d0e94aff6f52f00000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000100cf1a610768a5be99093399bd91888217a243909d01e3d967d8da86399f1ae86c68d6c93a867c5f6387e32828de45cec18e3c16e6cc573496f738ef78ebe3e654c33e59f45ed6964c7381cce894a8ee968a0e3b7749753ac762578d526a06ee46500c06e4c151bceac0c9d964e3cd7ec0cd7e01b1e6aa294638cb38736fdd6a7e090b0824ffc10ef5e4614fe3acf55a44e23e7e440ac54c5533572c8aa8d1539e5912f2e795a0423daa195666c92613ab9a40938c6967b54bffa4a25e52419775e91526e5030436ae9ed34f2212161ccf8ce29997518c9dd930820fef4979ea4d22e22f74ef64c0db4a4e6c9b007fb04a465cb8a74da3d4a9507ea921ce74d5dd00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000020935f3e0d513cd10b6f1099477cbc6133a0526f78967810e95aa6e306d7e417c200000000000000008b45a0730700000000000000000000007c26a17307000000000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000004e00000000000000000bf20a07307000000000000000000000074cda07307000000c09cae79149a38be21107dea9baa27f99cf2d7dc67986bd090ae9978c5a7c323cef54d7cb0139c57deedabb57b213ed11dda750aa0cf94e8ed064ae280a15e4412b356bea15d76928ed089cd13498380072f785a5e5c2968a4fb5d40e45724d25e86f231074e93273f939289cebd63bc25f5d536f2359198a07b9f48026b308ae59f643b409c1dca5b19af0ddf1fe8214ac51e3f8880112bca729a6b59be3b0d71fe63baff1d5d3571a76b94f73304d086792a769506a5c92ac4b19f022d7d2350b22b27492bab0b3d6e505d740cc7ffe6fe69a460da75ce5b47944925a64904d46cacdc51a955c930d9242e2a4ea863608859ed2dd8dffd4f8febbfc4034d79c88c3b640b69b61cdaafb5a7c94586a5bef7f58f1d319f39a7eaa592221b4b8948dffbef130b2fc704be0b382a5340bbf62cc648f5b69b8b79ec0983090a544a2eea7adec6275ff707b6389a00f589e34fdc910bfa6b00e665ba0e035b85582ceaa2d02f76548e5b574f65d2a1a554008c19b2a07e6633e4580419c9874ff6c75d6f5b9c44a04f1a1ecfaf96eef5bd68ebdab4c206918d17fb67b1c9a7a6bc937dae85e5b0368e24509726c8428eac201c4a397e66d3479406faf4f171b8428800cda77f40afb307a162930e7fc8e1a3914293872fc181406fd87885717b4228fe6b1689256c0d385f42f5bbe2027a22c1996e110ba97c171d3e5948de92bebdda6ba46ecf8a5004abcfcf6d2990dadf0dc5a039412e801e6c392f4c71e073aa68e1f84c54d24d24de924097a39c9532b9b7ac8d42564d975531360786101d7f893e908917775b62bff23294dbbe3a1cd8e6cc1c35b4801887b646a6f81f17fcddba7b592e3133393c16194fac7431abf2f5485ed711db282183c819e08ebaa8a8d7fe3af8caa085a7639a832001457dfb9128a8061142ad0335629ff23ff9cfeb3c337d7a51a6fbf00b9e34c52e1c9195c969bd4e7a0bfd51d5c5bed9c1167e71f0aa83cc32edfbefa9f4d3e0174ca85182eec9f3a09f6a6c0df6377a510d731206fa80a50bb6abe29085058f16212212a60eec8f049fecb92d8c8e0a84bc021352bfecbeddde993839f614c3dac0a3ee37543f9b412b16199dc158e23b544619e312724bb6d7c3153ed9de791d764a366b389af13c58bf8a8d90481a467657cdd2986268250628d0c10e385c58c6191e6fbe05191bcc04f133f2cea72c1c4848930bd7ba8cac54661072113fb278869e07bb8587f91392933374d017bcbe18869ff2c22b28cc10510d9853292803328be4fb0e80495e8bb8d271f5b889636b5fe28e79f1b850f8658246ce9b6a1e7b49fc06db7143e8fe0b4f2b0c5523a5c985e929f70af28d0bdd1a90a808f977f597c7c778c489e98d3bd8910d31ac0f7c6f67e02e6e4e1bdefb994c6098953f34636ba2b6ca20a4721d2b26a886722ff1c9a7e5ff1cf48b4ad1582d3f4e4a1004f3b20d8c5a2b71387a4254ad933ebc52f075ae229646b6f6aed19a5e372cf295081401eb893ff599b3f9acc0c0d3e7d328921deb59612076801e8cd61592107b5c67c79b846595cc6320c395b46362cbfb909fdb236ad2411b4e4883810a074b840464689986c3f8a8091827e17c32755d8fb3687ba3ba49f342c77f5a1f89bec83d811446e1a467139213d640b6a7455841b00000000000000000000000000000000000000000000000000000000000";
    bytes private constant verifyWithdrawalCredentialsCalldata =
        hex"3f65cf190000000000000000000000000000000000000000000000000000000066d052b800000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000001a000000000000000000000000000000000000000000000000000000000000007c0dd572606b2c28d28e0ef7466e38bf64b7da2b24aa043b401bc72709fb3ac50b3000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000608cc82a935ab0690a8d16f85d531ddd47072e71c80e26deefde89bd327688ac72855cddade1ac22f5a6e04b038c3cbb0018c0d441a33dd8524bcfb4f0f0e9e5a81e9756b225b336a1adfbf892392bf12aed19b206dfa39cba959a2d10ee9d7ac8000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000001b7f740000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000005c04ae64950c9655ff50ae0730e86bfa81fee362060439315c8ac0d3dc4b194109cccf5029c970218a966bc6d303e86f6ac73b92a79bce65d512ca26eb3f751e0e8de7f4d76942f674549064820f047fd3d95128b501a12b982ca7df32e929366d994d98ebba31128c604b81e52a0425f7e6f8d5a8e6c77de3d4912b65b28bf3fc4c8fd5df9dc556528e4309d3d9ebf385e8cc713e78d350ccf1f27a58407cd24a9114c3d3618a101f9c0b750c3fdde895a469291a77d58bbefc59fd15ce14b5cce7b1e2ca78679f2274aa45ca68ec4566356f893762ed43cfd7653b3316cf16ca8344e53b3014179b71033298aeb471e4ec02e6e148bcdaf4e739b101779c57b69bf32880bb27f0281aacc5dc3626a677ade4ecd6044e1da21815396c306733f6fe002e169136c2c5b091cfedd8e8962fc70fe11097b4d84dd56f1a187fffde596b9197e3be8255833e9f4cf79b408ec279dfd8dcb3df2ffd9edc72f5a2ea9978b971f9acb57936257eb7c99109f9ddb2f768ab53ede46547ce840f3d861b72dc291d065ebd67e3f6b59b3d9778fe933e7bcb62786d6ccb7c3de2d48b1a32461d1008bb3b0be57cdc7a532cae13bd6e2803e9c47db00ace45b2da0c418d97b162adb4803fa597d7bd836ad6a705e5e76eb1ac4f62b91f954e6e94b913c9a22a98b488ebb7d5642e73da3e49200df34030e0eb71cfe4ac3c97afe61826f5715b4a2ffb8508c2497db380f8eeec4a1ea5ffc698b3ddf75d5cd2219cff30a5db70816be8ae68a841ac9468d7dcd62f2d7f639e6dd8a4eb278343735c792880a36edd895eec8b2e541cad4e91de38385f2e046619f54496c2382cb6cacd5b98c26f5a44b8db0ff706f559e55ee28c25db647621a19533ea66713810661bbfafa79b889ce908c8eb66411d8ba4d5739fd40938385caca03d622aa49d9e2805ab7f4ab0f8a8d7fe3af8caa085a7639a832001457dfb9128a8061142ad0335629ff23ff9cfeb3c337d7a51a6fbf00b9e34c52e1c9195c969bd4e7a0bfd51d5c5bed9c1167e71f0aa83cc32edfbefa9f4d3e0174ca85182eec9f3a09f6a6c0df6377a510d731206fa80a50bb6abe29085058f16212212a60eec8f049fecb92d8c8e0a84bc021352bfecbeddde993839f614c3dac0a3ee37543f9b412b16199dc158e23b544619e312724bb6d7c3153ed9de791d764a366b389af13c58bf8a8d90481a467657cdd2986268250628d0c10e385c58c6191e6fbe05191bcc04f133f2cea72c1c4848930bd7ba8cac54661072113fb278869e07bb8587f91392933374d017bcbe18869ff2c22b28cc10510d9853292803328be4fb0e80495e8bb8d271f5b889636b5fe28e79f1b850f8658246ce9b6a1e7b49fc06db7143e8fe0b4f2b0c5523a5c985e929f70af28d0bdd1a90a808f977f597c7c778c489e98d3bd8910d31ac0f7c6f67e02e6e4e1bdefb994c6098953f34636ba2b6ca20a4721d2b26a886722ff1c9a7e5ff1cf48b4ad1582d3f4e4a1004f3b20d8c5a2b71387a4254ad933ebc52f075ae229646b6f6aed19a5e372cf295081401eb893ff599b3f9acc0c0d3e7d328921deb59612076801e8cd61592107b5c67c79b846595cc6320c395b46362cbfb909fdb236ad2411b4e4883810a074b840464689986c3f8a8091827e17c32755d8fb3687ba3ba49f342c77f5a1f89bec83d811446e1a467139213d640b6a74f7210d4f8e7e1039790e7bf4efa207555a10a6db1dd4b95da313aaa88b88fe76ad21b516cbc645ffe34ab5de1c8aef8cd4e7f8d2b51e8e1456adc7563cda206f19801b0000000000000000000000000000000000000000000000000000000000b1970500000000000000000000000000000000000000000000000000000000006ee51a529e8eb68716b00d8c8fb25f0f80e237e15d3b5b5ade88b75c4f2f8a8e905ceab6b758cdcf5f5bb4e0b59c38c9bb8b5c470fa9ec01d4f150d6f70a2158ad437e9408c70a2afb587a94bb7c735bcdb16314ae813445a1368647181db322f89868df21a5bf3fbdbb119a8ce6b0d7402b0b7788cb0fe3cef93e18308f096f000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000008e7c364a57c17ff1e55f66408036cdaeb4f65002fc3b2769f52f6dc3fa2048c090100000000000000000000006049d5afbfe642f05d2582ec9f60eef5fbab429d0040597307000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000066260100000000000000000000000000000000000000000000000000000000006c26010000000000000000000000000000000000000000000000000000000000ffffffffffffffff000000000000000000000000000000000000000000000000ffffffffffffffff000000000000000000000000000000000000000000000000";
}
