import hre from 'hardhat'

const main = async () => {
  const factory = await hre.ethers.getContractFactory('DelegNouns')
  const contract = await factory.deploy()
  await contract.waitForDeployment()
  console.info('Contract deployed to:', await contract.getAddress())
};

const runMain = async () => {
  try {
    await main()
    process.exit(0)
  } catch (error) {
    console.log(error)
    process.exit(1)
  }
}

runMain()
