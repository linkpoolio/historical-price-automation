# Historical Price | Chainlink Automation

This repository contains a smart contract, `HistoricalPrice`, which fetches and stores historical prices of a data feed using Chainlink Automation. The contract is designed to minimize gas fees by performing binary search off-chain and passing the result to an on-chain function.

## Features

- Fetches historical prices using Chainlink oracles
- Performs off-chain binary search to minimize gas fees
- Includes callback functionality for custom logic

## Requirements

- Foundry Forge (a CLI tool for Ethereum development)
- RPC URL (e.g. from Infura or Alchemy)
- Explorer API key (optional but recommended to verify contracts)

## Installation

### 1. Setup Foundry

[Installation instructions](https://book.getfoundry.sh/getting-started/installation)

```bash
# Download foundry
$ curl -L https://foundry.paradigm.xyz | bash

# Install foundry
$ foundryup
```

### 2. Install contract dependencies if changes have been made to contracts

```bash
$ make install
```

### 3. Setup environment variables

Set the following environment variables in your `.env` file:

```bash
RPC_URL=
EXPLORER_KEY=
PRIVATE_KEY=
MAINNET_RPC_URL=
```

### 4. Test contract

This will run a fork test on Mainnet, so make sure to have MAINNET_RPC_URL set in your `.env` file.

```bash
$ make test-contracts-all
```

### 5. Deploy contract

```bashtest-contracts-all
# Set RPC_URL to desired network and Explorer API key:
$ make deploy
```
