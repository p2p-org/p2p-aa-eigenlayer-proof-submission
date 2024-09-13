## p2p-aa-eigenlayer-proof-submission 

ERC-4337 Account abstraction contracts that allow

the **client** (account owner) to
- pre-pay ETH for gas
- set allowed operators
- set allowed arbitrary smart contract functions to be called by operators

**operators** to
- call arbitrary (pre-approved by the client) smart contract functions as [ERC-4337 UserOperations](https://www.erc4337.io/docs/understanding-ERC-4337/user-operation) via [EntryPoint](https://www.erc4337.io/docs/understanding-ERC-4337/entry-point-contract) using the client's pre-paid ETH to cover gas costs 

## Running tests

```shell
curl -L https://foundry.paradigm.xyz | bash
source /Users/$USER/.bashrc
foundryup
forge test
```

## Basic use case

1. Anyone (deployer, does not matter who) deploys `ProofSubmitterFactory`.
   
2. Client creates `ProofSubmitter` instance by calling `createProofSubmitter` function. Client can send ETH with the same `createProofSubmitter` call or later via `depositToEntryPoint` function.

3. Client sets operator via `setOperator` function.

4. Client sets allowed smart contract functions via `setAllowedFunctionForContract` function.

5. Operator sends UserOperation to a [ERC-4337 bundler](https://www.erc4337.io/bundlers) with one of the allowed smart contract functions called via `execute` function.

6. Client can withdraw remaining ETH from the `EntryPoint` at any time via `withdrawFromEntryPoint` function.

## Submitting EigenLayer proofs

Some of the EigenLayer functions are already allowed by default:

- `startCheckpoint` on EigenPod
- `verifyWithdrawalCredentials` on EigenPod
- `verifyCheckpointProofs` on EigenPod
- `processClaim` on RewardsCoordinator with the restriction that only the client can be the recipient.

However, for successfull execution

EigenPod functions require that 
- the `ProofSubmitter` contract owner is the pod owner
- `setProofSubmitter` on EigenPod has been called with the address of the `ProofSubmitter` contract

RewardsCoordinator's `processClaim` requires that 
- `setClaimerFor` on RewardsCoordinator has been called with the address of the `ProofSubmitter` contract

So, the flow will be the following:

1. Client becomes an EigenLayer pod owner by calling `createPod` on EigenPodManager.

2. Client creates `ProofSubmitter` instance by calling `createProofSubmitter` function. Client can send ETH with the same `createProofSubmitter` call or later via `depositToEntryPoint` function.

3. Client sets the P2P.org operator address via `setOperator` function on their `ProofSubmitter` contract instance.

4. Client sets the `ProofSubmitter` contract as a proofSubmitter for EigenPod by calling `setProofSubmitter` function on EigenPod.

5. Client sets the `ProofSubmitter` contract as a claimer for RewardsCoordinator by calling `setClaimerFor` function on RewardsCoordinator.

6. Client does an off-chain request (e.g. via P2P.org API) to submit a proofs for many validators.

7. P2P.org off-chain service generates all the required proofs.

8. P2P.org operator sends UserOperation to a [ERC-4337 bundler](https://www.erc4337.io/bundlers) with one of the allowed smart contract functions (e.g. `verifyCheckpointProofs`) called via the `ProofSubmitter` contract `execute` function.

9. The [ERC-4337 bundler](https://www.erc4337.io/bundlers) does the actual Ethereum transaction (call `verifyCheckpointProofs` on EigenPod via the `EntryPoint`'s `handleOps`, then `ProofSubmitter`'s `execute`) and get compensated for its gas using the client's pre-paid ETH.

10. P2P.org operator can repeat steps 7-9 for all the validators that the client has requested.


