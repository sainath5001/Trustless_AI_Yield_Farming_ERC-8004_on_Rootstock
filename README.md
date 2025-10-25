
# Trustless AI Yield Farming using ERC-8004 on Rootstock

This project implements a Trustless AI Yield Farming Bot using the ERC-8004 standard on Rootstock.
It combines identity, reputation, and validation layers to enable transparent, autonomous yield farming.

Smart Contracts Overview:

- Agent.sol – AI agent that executes yield strategies.

- IdentityRegistry.sol – Manages unique on-chain agent identities.

- ReputationRegistry.sol – Tracks and updates agent trust scores.

- ValidationRegistry.sol – Verifies agent actions for transparency.

- TrustlessVault.sol – Core vault managing deposits and yield distribution.

- JobCommitmentRegistry.sol - Contract is the backbone of the system’s claim to being truly     Trustless AI.

MockToken.sol – Test ERC-20 token for staking and rewards.


## Prerequisites

Before starting this tutorial, make sure you have a basic understanding of the following concepts and tools:

- Solidity
- Foundry
- Metamask
- Basic Knowledge of DeFi
- Rootstock

## Project Setup

Let’s start by creating a new directory for our project and setting up Foundry:

```
git clone https://github.com/sainath5001/Trustless_AI_Yield_Farming_ERC-8004_on_Rootstock.git
cd Trustless_AI_Yield_Farming_ERC-8004_on_Rootstock

forge install Openzeppelin/openzeppelin-contracts
forge remappings >> remappings.txt
```
Now that all our smart contracts are ready, let’s compile them using Foundry. In your terminal, run:

```
forge build
```

If you see “Compiler run successful!”, congratulations! 🎉

You have successfully compiled all your smart contracts, and they are now ready to be deployed to the Rootstock testnet.

## Testing Our Smart Contracts

Now that we have successfully built our contracts, it’s time to test them to ensure everything works as expected.

Foundry makes it easy to write and run tests for Solidity contracts. 
Inside your test directory, you can see file named VaultTest.t.sol

```
forge test
```
You should see output indicating which tests passed. A successful run confirms that all contracts are functioning correctly, and the system is ready for deployment.

🎉 All Tests Passed! 🎉

After running our Forge tests, we’ve verified that all smart contracts—IdentityRegistry, ReputationRegistry, ValidationRegistry, Agent, and TrustlessVault—work exactly as expected.

This means our trustless yield farming bot system is fully functional and ready for deployment.

✅ Users can stake tokens.
✅ Agents can register, gain reputation, and harvest rewards.
✅ Only validated agents can interact with the vault.

Before deploying our contracts, we need to create a .env file to store sensitive information like our wallet private key and the Rootstock Testnet RPC URL.

```
touch .env
nano .env
```
Add your variables:

```
PRIVATE_KEY=your_wallet_private_key_here
ROOTSTOCK_TESTNET_RPC=https://public-node.testnet.rsk.co
```

PRIVATE_KEY → The private key of your deployer wallet. Never share this publicly!

ROOTSTOCK_TESTNET_RPC → The RPC URL of the Rootstock Testnet node. This is how Forge connects to the network.

Load the .env file in the terminal so Forge can use it:

```
source .env
```

## Prepare for Deployment

We’ve completed and tested all smart contracts. The next step is to deploy them to the Rootstock Testnet.

To deploy your contracts:
```
forge script script/Deploy.s.sol --rpc-url <ROOTSTOCK_TESTNET_RPC> --broadcast --private-key $PRIVATE_KEY
```
Replace <ROOTSTOCK_TESTNET_RPC> with the Rootstock Testnet RPC URL.

Make sure your environment variable PRIVATE_KEY is set to your deployer account.

### 🎉 Congratulations! 🎉

Your trustless yield farming bot system is now live on the Rootstock Testnet. You can now interact with your contracts, stake tokens, and see agents in action!

## Verify Deployed Contracts

After deployment, you can easily confirm that all your contracts are live on the Rootstock Testnet.

Open the Rootstock Testnet Explorer: 
[Rootstock Testnet Explorer](https://explorer.testnet.rootstock.io/)

Check the contract details:
You’ll be able to see:

- Contract creation transaction
- Contract balance
- Verified source code (if you verified it)

## 🎉 Wrapping Up 

Great! Congratulations on building, testing, and deploying your Trustless Yield Farming Bot system on the Rootstock Testnet. You’ve successfully gone through the entire workflow—from creating smart contracts to running tests and deploying them live.




