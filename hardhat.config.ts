import type { HardhatUserConfig } from 'hardhat/config'
import { config } from 'dotenv'

import '@nomicfoundation/hardhat-ethers'
import 'hardhat-abi-exporter'

config()

import './tasks/dev-send-eth'

const hardhat: HardhatUserConfig = {
  solidity: {
    version: '0.8.19',
    settings: {
      optimizer: {
        enabled: true,
        runs: 10,
      },
    },
  },
  abiExporter: {
    flat: true,
    only: ['DelegNouns'],
  },
  networks: {},
}

if (process.env.SEPOLIA_RPC_URL && process.env.SEPOLIA_PRIVATE_KEY) {
  hardhat.networks = {
    ...hardhat.networks,
    sepolia: {
      timeout: 60000,
      url: process.env.SEPOLIA_RPC_URL,
      accounts: [
        process.env.SEPOLIA_PRIVATE_KEY,
      ],
    },
  }
}

if (process.env.MAINNET_RPC_URL && process.env.MAINNET_PRIVATE_KEY) {
  hardhat.networks = {
    ...hardhat.networks,
    mainnet: {
      timeout: 180000,
      url: process.env.MAINNET_RPC_URL,
      accounts: [
        process.env.MAINNET_PRIVATE_KEY,
      ],
    },
  }
}

export default hardhat
