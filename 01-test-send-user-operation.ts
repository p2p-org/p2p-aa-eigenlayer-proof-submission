import 'dotenv/config'
import { createPublicClient, http } from 'viem'
import { createBundlerClient } from 'viem/account-abstraction'
import {holesky} from 'viem/chains'

async function main() {
    try {
        const client = createPublicClient({
            chain: holesky,
            transport: http()
        })

        const bundlerClient = createBundlerClient({
            client,
            transport: http(`https://api.pimlico.io/v2/17069/rpc?apikey=${process.env.PIMLICO_API_KEY}`)
        })

        console.log(bundlerClient.chain.id)

        console.log('Done.')
    } catch (err) {
        console.log(err)
    }
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
