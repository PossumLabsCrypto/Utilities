from web3 import Web3
import os
import json
from dotenv import load_dotenv
from datetime import datetime
import requests

# Get time and print it
current_time = datetime.now()
formatted_time = current_time.strftime("%Y-%m-%d %H:%M:%S")
print(f"Time: {formatted_time}")
# ---------------------------------------------------------------------------


# Varibales
load_dotenv()  # Load .env file
BEARER = os.getenv("BEARER")  # Creat account in 1inch and get it
infura_api_key = os.getenv("infura_api_key")  # Creat account in Infura and get it
w3 = Web3(Web3.HTTPProvider(f"https://arbitrum-mainnet.infura.io/v3/{infura_api_key}"))
private_key = os.getenv("PRIVATEKEY")  # Your wallet Private Key
account_address = os.getenv("ACCOUNT")  # Your Account Address

psm_address = "0x17A8541B82BF67e10B0874284b4Ae66858cb1fd5"  # PSM token Address
contract_address = (
    "0xa94f0513b41e8C0c6E96B76ceFf2e28cAA3F5ebb"  # Converter contract Address
)

PSM = "0x17a8541b82bf67e10b0874284b4ae66858cb1fd5"
USDCE = "0xff970a61a04b1ca14834a43f5de4533ebddb5cc8"
USDC = "0xaf88d065e77c8cc2239327c5edb3a432268e5831"
WETH = "0x82af49447d8a07e3bd95bd0d56f35241523fbab1"
WBTC = "0x2f2a2543b76a4166549f7aab2e75bef0aefc5b0f"
LINK = "0xf97f4df75117a78c1a5a0dbb814af92458539fb4"
ARB = "0x912ce59144191c1204e64559fe8253a0e49e6548"
Portal_USDCE = "0xE8EfFf304D01aC2D9BA256b602D736dB81f20984"  # USDCE portal Address
Portal_USDC = "0x9167CFf02D6f55912011d6f498D98454227F4e16"
Portal_ARB = "0x523a93037c47Ba173E9080FE8EBAeae834c24082"
Portal_WBTC = "0x919B37b5f2f1DEd2a1f6230Bf41790e27b016609"
Portal_WETH = "0xe771545aaDF6feC3815B982fe2294F7230C9c55b"
Portal_LINK = "0x51623b54753E07Ba9B3144Ba8bAB969D427982b6"
Portals = [
    {"name": "USDCE", "address": Portal_USDCE, "decimals": 6, "token": USDCE},
    {"name": "USDC", "address": Portal_USDC, "decimals": 6, "token": USDC},
    {"name": "WETH", "address": Portal_WETH, "decimals": 18, "token": WETH},
    {"name": "WBTC", "address": Portal_WBTC, "decimals": 8, "token": WBTC},
    {"name": "LINK", "address": Portal_LINK, "decimals": 18, "token": LINK},
    {"name": "ARB", "address": Portal_ARB, "decimals": 18, "token": ARB},
]
gas = 2500000
decimal_18 = 10**18
decimal_6 = 10**6
# ------------------------------------------------------------------------


# GET PRICES from 1inch
method = "get"
apiUrl = "https://api.1inch.dev/price/v1.1/42161"
requestOptions = {
    "headers": {"Authorization": f"Bearer {BEARER}"},
    "body": {
        "tokens": [
            f"{WETH}",
            f"{WBTC}",
            f"{LINK}",
            f"{ARB}",
            f"{USDCE}",
            f"{USDC}",
            f"{PSM}",
        ],
        "currency": "USD",
    },
    "params": {},
}
headers = requestOptions.get("headers", {})
body = requestOptions.get("body", {})
params = requestOptions.get("params", {})
response = requests.post(apiUrl, headers=headers, json=body, params=params)
data = response.json()

PSM_price = 100000 * float(data[PSM])
if PSM_price == 0:
    PSM_price = float(os.getenv("PSMPRICE"))  # Price of 100K PSM token

profit = float(os.getenv("PROFIT"))  # Profit that expected
total = PSM_price + profit
print(f"100K psm price: {PSM_price:.3f}, PRICE + PROFIT = total: {total:.3f}")

# ----------------------------------------------------------------------

current_directory = os.path.dirname(__file__)  # Get the current directory of the script
converter_path = os.path.join(current_directory, "Converter.json")
psm_path = os.path.join(current_directory, "psm.json")

# Get contracts functions
with open(converter_path, "r") as abi_file:
    contract_abi = json.load(abi_file)
with open(psm_path, "r") as abi_file:
    psm_abi = json.load(abi_file)

account = w3.eth.account.from_key(private_key)
contract = w3.eth.contract(address=contract_address, abi=contract_abi)
functions = contract.functions
psm_contract = w3.eth.contract(address=psm_address, abi=psm_abi)
psm_functions = psm_contract.functions
# -------------------------------------------------------------------


# Get PSM balance of account and print it
balance = psm_functions.balanceOf(account_address).call()
print(f"PSM Balance: {(balance/decimal_18):.2f}")
# -------------------------------------------------------------------


# V1 reward
v1_reward_usdce = functions.V1_getRewardsUSDCE().call()
print(f"v1 reward USDCE: {(v1_reward_usdce / decimal_6):.2f}")
if psm_functions.balanceOf(account_address).call() >= 10**23:
    if (v1_reward_usdce / decimal_6) >= total:
        # Encode the function call
        transaction_data = functions.V1_convertUSDCE(
            account_address, 1
        ).build_transaction(
            {
                "gas": gas,
                "gasPrice": w3.eth.gas_price,
                "nonce": w3.eth.get_transaction_count(account.address),
                "value": 0,
            }
        )
        signed_transaction = w3.eth.account.sign_transaction(
            transaction_data, private_key
        )
        transaction_hash = w3.eth.send_raw_transaction(
            signed_transaction.rawTransaction
        )
        print(f"USDCE V1 Transaction sent. Hash: {transaction_hash.hex()}")
        print(f"USDCE V1 PROFIT: {(v1_reward_usdce-PSM_price):.2f}")
# -------------------------------------------------------------------


# V2 reward
for portal in Portals:
    portal_address = portal["address"]
    name = portal["name"]
    decimals = 10 ** portal["decimals"]
    token = portal["token"]
    v2_reward = functions.V2_getRewards(portal_address).call()
    worth = v2_reward * float(data[token]) / decimals
    print(f"v2 reward {name}: {(v2_reward / decimals):.4f}, worth: {worth:.4f}")

    if psm_functions.balanceOf(account_address).call() >= 10**23:
        if worth >= total:
            # Encode the function call
            transaction_data = functions.V2_convert(
                portal_address, account_address, v2_reward
            ).build_transaction(
                {
                    "gas": gas,
                    "gasPrice": w3.eth.gas_price,
                    "nonce": w3.eth.get_transaction_count(account.address),
                    "value": 0,
                }
            )
            signed_transaction = w3.eth.account.sign_transaction(
                transaction_data, private_key
            )
            transaction_hash = w3.eth.send_raw_transaction(
                signed_transaction.rawTransaction
            )
            print(f"{name} Transaction sent. Hash: {transaction_hash.hex()}")
            print(f"{name} PROFIT: {(worth-PSM_price):.4f}")
# -------------------------------------------------------------------
