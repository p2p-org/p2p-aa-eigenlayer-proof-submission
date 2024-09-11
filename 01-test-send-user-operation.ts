import 'dotenv/config'
import {
    Address,
    createPublicClient,
    encodeFunctionData,
    Hex,
    http,
    SignableMessage
} from 'viem'
import {
    createBundlerClient,
    entryPoint06Abi,
    entryPoint06Address,
    getUserOperationHash,
    toSmartAccount, UserOperation
} from 'viem/account-abstraction'
import {holesky} from 'viem/chains'
import {privateKeyToAccount} from "viem/accounts";
import {getAccountNonce} from "permissionless/actions";
import {signMessage} from "viem/actions";

async function main() {
    try {
        const client = createPublicClient({
            chain: holesky,
            transport: http("https://rpc.ankr.com/eth_holesky")
        })

        const owner = privateKeyToAccount(process.env.PRIVATE_KEY as Hex)

        const getFactoryArgs: () => Promise<{ factory?: Address | undefined; factoryData?: Hex | undefined }> = async () => {
            return ({
                factory: '0x9d979efFFce38D910979BbF4177894cd8817220B' as Address,
                factoryData: encodeFunctionData({
                    abi: factoryAbi,
                    functionName: "createProofSubmitter"
                }) as Hex
            })
        }

        const account = await toSmartAccount({
            getFactoryArgs,
            async getStubSignature() {
                return "0x"
            },
            signMessage(parameters: { message: SignableMessage }): Promise<Hex> {
                throw new Error("Isn't 1271 compliant")
            },
            signTypedData(): Promise<Hex> {
                throw new Error("Isn't 1271 compliant")
            },
            async signUserOperation(parameters) {
                const {...userOperation} = parameters
                return signMessage(client, {
                    account: owner,
                    message: {
                        raw: getUserOperationHash({
                            userOperation: {
                                ...userOperation,
                                sender:
                                    userOperation.sender ??
                                    (await this.getAddress()),
                                signature: "0x"
                            } as UserOperation,
                            entryPointAddress: entryPoint06Address,
                            entryPointVersion: '0.6',
                            chainId: 17000
                        })
                    }
                })
            },
            client,
            entryPoint: {
                abi: entryPoint06Abi,
                address: entryPoint06Address,
                version: '0.6',
            },

            async encodeCalls(calls) {
                if (calls.length === 1)
                    return encodeFunctionData({
                        abi,
                        functionName: 'execute',
                        args: [calls[0].to, calls[0].data ?? '0x'],
                    })
                return encodeFunctionData({
                    abi,
                    functionName: 'executeBatch',
                    args: [
                        calls.map(c => c.to),
                        calls.map(c => c.data ?? '0x'),
                    ],
                })
            },
            async getAddress() {
                return '0x80509AA12753582aA4CF4D0Cc3781D35099d0f5d'
            },
            async getNonce(args) {
                return getAccountNonce(client, {
                    address: await this.getAddress(),
                    entryPointAddress: entryPoint06Address,
                    key: args?.key
                })
            }
        })

        const bundlerClient = createBundlerClient({
            account,
            client,
            transport: http(`https://api.pimlico.io/v2/17069/rpc?apikey=${process.env.PIMLICO_API_KEY}`)
        })

        const hash = await bundlerClient.sendUserOperation({
            calls: [
                {
                    abi: abi,
                    functionName: 'execute',
                    to: '0xEf0E898C1013dd59f03A66947690Aa58F8A5F578',
                    args: ['0xAcc1fb458a1317E886dB376Fc8141540537E68fE', '0x3ccc861d0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000D5e069BC58dedb2a3A348995ee753Eef0274004F000000000000000000000000000000000000000000000000000000000000004b00000000000000000000000000000000000000000000000000000000000192350000000000000000000000000000000000000000000000000000000000000100000000000000000000000000D5e069BC58dedb2a3A348995ee753Eef0274004F95f0093489d51d9e2f039ed2fce75382c01a534a81d210f9dac82c7e27aea19f0000000000000000000000000000000000000000000000000000000000000340000000000000000000000000000000000000000000000000000000000000038000000000000000000000000000000000000000000000000000000000000003e000000000000000000000000000000000000000000000000000000000000002206bd8b8552455002951ab0141d76f12d24ce2c75a916c88d55bad21e2573e30d81ff53126be651b2ee23ac0978db0ef57249f7024fb2975b67d33832b92cf25fd7b04224e2508aa18c9a5e141fe1b7bab61541c90282dd771d4c4efc651f202671563a379cd034e64b2138864dacd05f1b998b6a1c18f8cb6527d095b991581fb595adee1ce007161da3247b0fcc1b312d1c57537320517c837c68e3b89d233cd0bb2251248851a8cbc96be2de63cde11ba6986fc0e43bf73fc8eea7401cb254d73c6c73c96e04e8a79491b6eccfecbac37be3cc3c0444fd858aab9b1169eb73735487409170623edc2b4714fe99ad5291f584eea5b9073ef7d2ef22606d75164835bce9ca91fb56c57318fecc85403388fe1d2e034f25ce84e719aa45cad462f9058dd5a949125136139812a13d649923e924df607f4c17211cbf4f046288ac7b0ede366758f6abf153ed2c8d3580de3144ec6777ce6281ba50f1a3eda93611deaea3a4ceef182b0fe8cbfb7c58b2f84ba7f234db49a8007d345445247d63594061228864e78b39c7de495c2953ceee805987b2d278c72b87e7ca9029e514f37ba20cf2d697283f958e4a32a88c15ecb5c2476aa7e6f26e8da1e924c763c582ae44946784deda2609277e536824a70e81e515aa6e84328cce37e519abeac06689964710330b3195b2aaa356608d28666e4c3b3f97a54addece11f91b81ce1f0c5d5dab4d4bb07541c125acd5ee0a8a77170289b87a9e4b99e699f6b28843d2e7000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000deeeee2b48c121e6728ed95c860e29617784993200000000000000000000000000000000000000000000005264d3061ea97744f0']
                }
            ],
        })

        const receipt = await bundlerClient.waitForUserOperationReceipt({
            hash: hash
        })

        console.log(receipt)

        console.log('Done.')
    } catch (err) {
        console.log(err)
    }
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

const abi = [{"inputs":[{"internalType":"contract IProofSubmitterFactory","name":"_factory","type":"address"}],"stateMutability":"nonpayable","type":"constructor"},{"inputs":[{"internalType":"address","name":"_passedAddress","type":"address"}],"name":"Erc4337Account__NotEntryPoint","type":"error"},{"inputs":[{"internalType":"address","name":"_passedAddress","type":"address"},{"internalType":"address","name":"_owner","type":"address"}],"name":"Erc4337Account__NotOwner","type":"error"},{"inputs":[{"internalType":"address","name":"_caller","type":"address"}],"name":"ProofSubmitter__CallerNeitherEntryPointNorOwner","type":"error"},{"inputs":[{"internalType":"address","name":"_caller","type":"address"}],"name":"ProofSubmitter__CallerNeitherOperatorNorOwner","type":"error"},{"inputs":[],"name":"ProofSubmitter__DataTooShort","type":"error"},{"inputs":[{"internalType":"address","name":"_target","type":"address"},{"internalType":"bytes4","name":"_selector","type":"bytes4"}],"name":"ProofSubmitter__NotAllowedToCall","type":"error"},{"inputs":[{"internalType":"address","name":"_caller","type":"address"},{"internalType":"address","name":"_factory","type":"address"}],"name":"ProofSubmitter__NotFactoryCalled","type":"error"},{"inputs":[],"name":"ProofSubmitter__OwnerShouldHaveEigenPod","type":"error"},{"inputs":[{"internalType":"uint256","name":"_targetsLength","type":"uint256"},{"internalType":"uint256","name":"_dataLength","type":"uint256"}],"name":"ProofSubmitter__WrongArrayLengths","type":"error"},{"inputs":[],"name":"ProofSubmitter__ZeroAddressOwner","type":"error"},{"anonymous":false,"inputs":[{"indexed":false,"internalType":"address","name":"_contract","type":"address"},{"indexed":false,"internalType":"bytes4","name":"_selector","type":"bytes4"}],"name":"ProofSubmitter__AllowedFunctionForContractRemoved","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"_contract","type":"address"},{"indexed":true,"internalType":"bytes4","name":"_selector","type":"bytes4"},{"components":[{"components":[{"internalType":"enum ProofSubmitterStructs.RuleType","name":"ruleType","type":"uint8"},{"internalType":"uint32","name":"bytesCount","type":"uint32"},{"internalType":"uint32","name":"startIndex","type":"uint32"}],"internalType":"struct ProofSubmitterStructs.Rule","name":"rule","type":"tuple"},{"internalType":"bytes","name":"allowedBytes","type":"bytes"}],"indexed":false,"internalType":"struct ProofSubmitterStructs.AllowedCalldata","name":"_allowedCalldata","type":"tuple"}],"name":"ProofSubmitter__AllowedFunctionForContractSet","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"internalType":"address","name":"_owner","type":"address"}],"name":"ProofSubmitter__Initialized","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"internalType":"address","name":"_operator","type":"address"}],"name":"ProofSubmitter__OperatorDismissed","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"internalType":"address","name":"_newOperator","type":"address"}],"name":"ProofSubmitter__OperatorSet","type":"event"},{"inputs":[],"name":"depositToEntryPoint","outputs":[],"stateMutability":"payable","type":"function"},{"inputs":[{"internalType":"address","name":"_operator","type":"address"}],"name":"dismissOperator","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_target","type":"address"},{"internalType":"bytes","name":"_data","type":"bytes"}],"name":"execute","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address[]","name":"_targets","type":"address[]"},{"internalType":"bytes[]","name":"_data","type":"bytes[]"}],"name":"executeBatch","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"factory","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_target","type":"address"},{"internalType":"bytes4","name":"_selector","type":"bytes4"}],"name":"getAllowedCalldata","outputs":[{"components":[{"components":[{"internalType":"enum ProofSubmitterStructs.RuleType","name":"ruleType","type":"uint8"},{"internalType":"uint32","name":"bytesCount","type":"uint32"},{"internalType":"uint32","name":"startIndex","type":"uint32"}],"internalType":"struct ProofSubmitterStructs.Rule","name":"rule","type":"tuple"},{"internalType":"bytes","name":"allowedBytes","type":"bytes"}],"internalType":"struct ProofSubmitterStructs.AllowedCalldata","name":"","type":"tuple"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"getBalance","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_owner","type":"address"}],"name":"initialize","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_target","type":"address"},{"internalType":"bytes4","name":"_selector","type":"bytes4"},{"internalType":"bytes","name":"_calldataAfterSelector","type":"bytes"}],"name":"isAllowedCalldata","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_address","type":"address"}],"name":"isOperator","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"owner","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_contract","type":"address"},{"internalType":"bytes4","name":"_selector","type":"bytes4"}],"name":"removeAllowedFunctionForContract","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_contract","type":"address"},{"internalType":"bytes4","name":"_selector","type":"bytes4"},{"components":[{"components":[{"internalType":"enum ProofSubmitterStructs.RuleType","name":"ruleType","type":"uint8"},{"internalType":"uint32","name":"bytesCount","type":"uint32"},{"internalType":"uint32","name":"startIndex","type":"uint32"}],"internalType":"struct ProofSubmitterStructs.Rule","name":"rule","type":"tuple"},{"internalType":"bytes","name":"allowedBytes","type":"bytes"}],"internalType":"struct ProofSubmitterStructs.AllowedCalldata","name":"_allowedCalldata","type":"tuple"}],"name":"setAllowedFunctionForContract","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_newOperator","type":"address"}],"name":"setOperator","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"bytes4","name":"interfaceId","type":"bytes4"}],"name":"supportsInterface","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[{"components":[{"internalType":"address","name":"sender","type":"address"},{"internalType":"uint256","name":"nonce","type":"uint256"},{"internalType":"bytes","name":"initCode","type":"bytes"},{"internalType":"bytes","name":"callData","type":"bytes"},{"internalType":"uint256","name":"callGasLimit","type":"uint256"},{"internalType":"uint256","name":"verificationGasLimit","type":"uint256"},{"internalType":"uint256","name":"preVerificationGas","type":"uint256"},{"internalType":"uint256","name":"maxFeePerGas","type":"uint256"},{"internalType":"uint256","name":"maxPriorityFeePerGas","type":"uint256"},{"internalType":"bytes","name":"paymasterAndData","type":"bytes"},{"internalType":"bytes","name":"signature","type":"bytes"}],"internalType":"struct UserOperation","name":"userOp","type":"tuple"},{"internalType":"bytes32","name":"userOpHash","type":"bytes32"},{"internalType":"uint256","name":"missingAccountFunds","type":"uint256"}],"name":"validateUserOp","outputs":[{"internalType":"uint256","name":"validationData","type":"uint256"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"withdrawFromEntryPoint","outputs":[],"stateMutability":"nonpayable","type":"function"}] as const
const factoryAbi = [{"inputs":[],"stateMutability":"nonpayable","type":"constructor"},{"inputs":[],"name":"createProofSubmitter","outputs":[{"internalType":"contract ProofSubmitter","name":"proofSubmitter","type":"address"}],"stateMutability":"payable","type":"function"},{"inputs":[],"name":"entryPoint","outputs":[{"internalType":"address payable","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"getReferenceProofSubmitter","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"i_referenceProofSubmitter","outputs":[{"internalType":"contract ProofSubmitter","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_owner","type":"address"}],"name":"predictProofSubmitterAddress","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"bytes4","name":"interfaceId","type":"bytes4"}],"name":"supportsInterface","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"}] as const
