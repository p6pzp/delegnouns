import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { task, types } from 'hardhat/config'

task('dev-send-eth', 'Send some ETH to address')
.addParam('from', 'Internal signer', 0, types.int)
.addParam('address', 'Given "to" address')
.addParam('eth', 'Value to send')
.setAction(async (
  { from, address, eth }: { from: number, address: string, eth: string },
  hre: HardhatRuntimeEnvironment
) => {
  if (
    hre.hardhatArguments.network !== 'hardhat' &&
    hre.hardhatArguments.network !== 'localhost'
  ) {
    console.error('error: Development transfer can only be done in hardhat network')
    process.exit(1)
  }

  if (!hre.ethers.isAddress(address)) {
    console.error('error: Given address is not valid')
    process.exit(1)
  }

  const value = hre.ethers.parseEther(eth)

  const signers = await hre.ethers.getSigners()

  if (!signers[from]) {
    console.error('error: Internal signer not found')
    process.exit(1)
  }

  const fromAddress = await signers[from].getAddress()

  const tx = await signers[from].sendTransaction({
    to: address,
    value,
  })

  console.log(`ETH ${value} sent from ${fromAddress} to ${address} on ${tx.hash}`)
})
