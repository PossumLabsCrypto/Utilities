import os
import logging
import json

from web3 import Web3
from eth_account import Account
from dotenv import load_dotenv

load_dotenv()

log_filename = "possum-bot.log"
logging.basicConfig(
    filename=log_filename,
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
)


class PossumBot:
    def __init__(self, rpc_url, contract_address, abi_path, private_key):
        self.web3 = Web3(Web3.HTTPProvider(rpc_url))
        self.contract_address = contract_address
        self.contract = self.web3.eth.contract(
            address=self.contract_address, abi=json.load(open(abi_path))
        )
        self.private_key = private_key
        self.wallet = Account.from_key(self.private_key)

    def chain_id(self):
        return self.web3.eth.chain_id

    def get_payload(self):
        return {
            "chainId": self.chain_id(),
            "from": self.wallet.address,
            "nonce": self.web3.eth.get_transaction_count(self.wallet.address),
            "gas": 2_000_000,
        }

    def convert(self, orderId):
        logging.info(f"Executing arbitrage  {orderId = }")

        call_function = self.contract.functions.executeArbitrage(
            self.wallet.address, orderId
        ).build_transaction(self.get_payload())

        signed_tx = self.web3.eth.account.sign_transaction(
            call_function, private_key=self.private_key
        )

        send_tx = self.web3.eth.send_raw_transaction(signed_tx.rawTransaction)

        tx_receipt = self.web3.eth.wait_for_transaction_receipt(send_tx)

        logging.info(f"TX HASH: {tx_receipt.transactionHash.hex()}")

    def run(self):
        logging.info(f"Bot startup...")
        self.check_arbitrage()

    def get_order_id(self):
        return self.contract.functions.orderIndex().call()

    def _check_arbitrage(self, orderId):
        logging.info(f"Checking arbitrage {orderId = }")

        canExecute = self.contract.functions["checkArbitrage"](orderId).call()[0]

        if canExecute:
            self.convert(orderId)

    def check_arbitrage(self):
        order_index = self.get_order_id()
        for i in range(order_index):
            self._check_arbitrage(i)


if __name__ == "__main__":
    bot = PossumBot(
        rpc_url="https://arbitrum-one.publicnode.com",
        contract_address="0x4f0fe6A8287f3bEbA2754220FC1AAF2a07A56c7C",
        abi_path="./abi.json",
        private_key=os.getenv("PRIVATE_KEY"),
    )
    bot.run()
