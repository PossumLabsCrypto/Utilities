## Arbitrage Executor

Welcome to the Arbitrage Executor! This simple web application helps you automate arbitrage transactions on the Arbitrum network. Follow these steps to set it up and start using it.

### Setup Instructions

1. **Open the HTML File**
   - Save the provided HTML code as a file named `arbitrage.html`.
   - Open `arbitrage.html` in your web browser.

2. **Input Required Information**

   - **Recipient Reward Address**
     - Enter the Ethereum address where rewards should be sent.

   - **RPC Provider**
     - Choose an RPC provider (Alchemy, Infura, or Arbitrum Public Node).
     - If you select Alchemy or Infura, an additional input field for the API Key will appear. Enter your API Key.

   - **Private Key**
     - Enter your Ethereum wallet's private key. This will be used to sign transactions.

   - **Auto-refresh Timer**
     - Set the auto-refresh timer in seconds. This determines how frequently the app checks for executable orders.

3. **Save Settings**

   - Click the "Save" button to store your settings and start the auto-refresh timer.

### How It Works

1. **Fetch Orders**
   - The app will connect to the smart contract and retrieve the current orders.
   - Orders that can be executed are displayed in the "Orders" section.

2. **Execute Orders**
   - If an order meets the arbitrage criteria, it will be executed automatically.
   - The transaction status will be displayed under each order.

### Important Notes

- **Private Key Security**
  - Ensure your private key is kept secure. Never share it with anyone.
  - After saving, the private key input field will show "private key saved" for security reasons.

- **Transaction Costs**
  - Transactions require gas. Ensure your wallet has enough ETH to cover these costs.

### Dependencies

- **Web3.js**
  - The app uses Web3.js to interact with the Ethereum blockchain. The Web3.js library is loaded from a CDN.

### Troubleshooting

- **Error Fetching Orders**
  - If you see an error message while fetching orders, ensure your settings are correct and try again.
  
- **Transaction Failures**
  - If a transaction fails, check the error message for details. Ensure you have enough gas and that the private key is correct.


---

Enjoy using the Arbitrage Executor! If you encounter any issues or have questions, feel free to reach out for support.