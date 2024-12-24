import json
import solcx
from web3 import Web3
from dotenv import load_dotenv
import os

# load environment variables
load_dotenv()

SOLIDITY_VERSION = "0.8.0"

with open("./updraft_course/SimpleStorage.sol", "r") as file:
    simple_storage_file = file.read()

solcx.install_solc(SOLIDITY_VERSION)
compiled_sol = solcx.compile_standard(
    {
        "language": "Solidity",
        "sources": {"SimpleStorage.sol": {"content": simple_storage_file}},
        "settings": {
            "outputSelection": {
                "*": {"*": ["abi", "metadata", "evm.bytecode", "evm.sourceMap"]},
            },
        },
    },
    solc_version=SOLIDITY_VERSION,
)

with open("compiled_code.json", "w") as file:
    json.dump(compiled_sol, file, indent=4)

# get bytecode and ABI
bytecode = compiled_sol["contracts"]["SimpleStorage.sol"]["SimpleStorage"]["evm"]["bytecode"]["object"]
abi = compiled_sol["contracts"]["SimpleStorage.sol"]["SimpleStorage"]["abi"]

# connect to ganache
w3 = Web3(Web3.HTTPProvider("http://localhost:7545"))
actual_chain_id = w3.eth.chain_id
print(f"Connected to network with chain ID: {actual_chain_id}")
chain_id = 1337  # Ganache's actual chain ID (different from network ID shown in GUI)
my_address = os.getenv("MY_ADDRESS")
private_key = os.getenv("PRIVATE_KEY")

if not my_address or not private_key:
    raise ValueError("Please set MY_ADDRESS and PRIVATE_KEY in .env file")

# create the contract in python
SimpleStorage = w3.eth.contract(abi=abi, bytecode=bytecode)

# get the latest transaction
nonce = w3.eth.get_transaction_count(my_address)

# build a transaction
transaction = SimpleStorage.constructor().build_transaction(
    {"chainId": chain_id, "from": my_address, "nonce": nonce}
)

# sign the transaction
signed_txn = w3.eth.account.sign_transaction(transaction, private_key=private_key)
# send the transaction
tx_hash = w3.eth.send_raw_transaction(signed_txn.raw_transaction)
# wait for the transaction to be mined
tx_receipt = w3.eth.wait_for_transaction_receipt(tx_hash)

print(f"Contract deployed to {tx_receipt.contractAddress}")

# retrieve the value using call
simple_storage = w3.eth.contract(address=tx_receipt.contractAddress, abi=abi)
print(simple_storage.functions.retrieve().call())

# store a new value
store_transaction = simple_storage.functions.store(718).build_transaction(
    {"chainId": chain_id, "from": my_address, "nonce": nonce + 1}
)
signed_store_txn = w3.eth.account.sign_transaction(store_transaction, private_key=private_key)
send_store_tx = w3.eth.send_raw_transaction(signed_store_txn.raw_transaction)
tx_receipt = w3.eth.wait_for_transaction_receipt(send_store_tx)

print("Updated favorite number")
print(simple_storage.functions.retrieve().call())
