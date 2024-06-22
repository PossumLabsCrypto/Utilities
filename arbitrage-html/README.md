# Arbitrage Executor

This project provides a web interface to execute arbitrage operations on the Arbitrum blockchain. It allows users to interact with a smart contract deployed at a specific address (`0x4f0fe6a8287f3beba2754220fc1aaf2a07a56c7c`) using Web3.js.

## Features

- **Recipient Reward Address**: Input field to specify the address that will receive rewards from arbitrage executions.
- **RPC Provider Selection**: Radio buttons to choose between different RPC providers (Alchemy, Infura, or Arbitrum Public Node).
- **API Key**: Input field (displayed conditionally) to provide API keys required by certain RPC providers.
- **Private Key**: Input field to enter the private key associated with the wallet that will sign and send transactions.
- **Auto-refresh Timer**: Input field to set the interval (in seconds) for automatically fetching and updating the list of executable arbitrage orders.
- **Save Button**: Saves the user settings (RPC provider, API key, refresh timer) and initializes the Web3 provider.
- **Countdown Timer**: Displays the time remaining until the next automatic refresh.
- **Executable Orders**: Displays the list of orders that can be executed, fetched from the smart contract.
- **Execute Button**: Allows users to execute a selected arbitrage order by signing and sending a transaction to the contract.

## Usage

1. **Setup**: Enter the recipient reward address, private key, select an RPC provider, and optionally enter an API key if required.
2. **Save**: Click the "Save" button to store the settings and initialize the Web3 provider based on the selected RPC provider and API key.
3. **Automatic Refresh**: The application will automatically fetch executable orders at the specified interval (`Auto-refresh Timer`) and display them.
4. **Execution**: Click the "Execute" button next to an order to initiate an arbitrage transaction. Confirm the transaction using your wallet.

## Development

### Prerequisites

- Web browser with Web3.js support.
- Access to the Arbitrum network or chosen RPC provider (Alchemy, Infura, Arbitrum Public Node).
- Private key associated with an Ethereum wallet for signing transactions.

### Libraries and Tools

- **Web3.js**: Library for interacting with the Ethereum blockchain.
- **JavaScript**: Programming language used for frontend logic.
- **HTML/CSS**: Structure and styling of the user interface.

### Deployment

- Host the `arbitrage.html` file on a web server or local environment accessible via a web browser.
- Ensure the RPC provider (Alchemy, Infura, or Arbitrum Public Node) is accessible and properly configured with API keys if required.