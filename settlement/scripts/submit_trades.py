from web3 import Web3
from eth_account import Account
import json
import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Connect to your network (e.g., local Anvil)
w3 = Web3(Web3.HTTPProvider('http://localhost:8545'))

# Load contract ABIs
with open('../out/ConcreteSettlement.sol/ConcreteNativeOrdersSettlement.json') as f:
    settlement_abi = json.load(f)['abi']

with open('../out/TestERC20.sol/TestERC20.json') as f:
    token_abi = json.load(f)['abi']

# Contract addresses from deployment
SETTLEMENT_ADDRESS = "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9"
CASH_TOKEN_ADDRESS = "0x5FbDB2315678afecb367f032d93F642f64180aa3"
SECURITY_TOKEN_ADDRESS = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512"

# Initialize contracts
settlement = w3.eth.contract(address=SETTLEMENT_ADDRESS, abi=settlement_abi)
cash_token = w3.eth.contract(address=CASH_TOKEN_ADDRESS, abi=token_abi)
security_token = w3.eth.contract(address=SECURITY_TOKEN_ADDRESS, abi=token_abi)

def submit_trade(trade):
    try:
        # Convert trade data to contract format
        limit_order = (
            Web3.to_checksum_address(trade['makerToken']),  # address
            Web3.to_checksum_address(trade['takerToken']),  # address
            int(trade['makerAmount']),  # uint128
            int(trade['takerAmount']),  # uint128
            0,  # protocolFeeAmount (uint128)
            Web3.to_checksum_address(trade['maker']),  # address
            Web3.to_checksum_address(trade['taker']),  # address
            Web3.to_checksum_address(trade['sender']),  # address
            Web3.to_checksum_address(trade['feeRecipient']),  # address
            bytes.fromhex(trade['pool'].replace('0x', '')),  # bytes32
            int(trade['expiration']),  # uint64
            int(trade['salt']),  # uint256
            trade['makerIsBuyer']  # bool
        )

        # Convert hex strings to bytes for signature components
        signatures = (
            2,  # signatureType (uint8) for EIP712
            int(trade['maker_v']),  # uint8
            bytes.fromhex(trade['maker_r'].replace('0x', '')),  # bytes32
            bytes.fromhex(trade['maker_s'].replace('0x', '')),  # bytes32
            int(trade['taker_v']),  # uint8
            bytes.fromhex(trade['taker_r'].replace('0x', '')),  # bytes32
            bytes.fromhex(trade['taker_s'].replace('0x', ''))   # bytes32
        )

        print("Limit Order:", limit_order)
        print("Signatures:", signatures)

        # Build transaction
        tx = settlement.functions.fillLimitOrder(
            limit_order,  # LimitOrder struct
            signatures,   # Signature struct
            int(trade['takerAmount'])  # takerTokenFillAmount (uint128)
        ).build_transaction({
            'from': w3.eth.accounts[0],
            'gas': 500000,
            'gasPrice': w3.eth.gas_price,
            'nonce': w3.eth.get_transaction_count(w3.eth.accounts[0]),
            'chainId': 31337  # Add chainId for Anvil
        })

        print("Transaction details:", tx)

        # Sign and send transaction
        private_key = os.getenv('ACCOUNT_0_PRIVATE_KEY')
        if not private_key:
            raise ValueError("Private key not found in environment variables")
        
        print("Using private key:", private_key[:6] + "..." + private_key[-4:])
        
        signed_tx = w3.eth.account.sign_transaction(tx, private_key=private_key)
        print("Signed transaction:", signed_tx)
        
        # Changed rawTransaction to raw_transaction
        tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)
        print("Transaction hash:", tx_hash.hex())
        
        # Wait for transaction receipt
        receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
        return receipt

    except Exception as e:
        print(f"Error in submit_trade: {str(e)}")
        print(f"Error type: {type(e)}")
        import traceback
        traceback.print_exc()
        raise

def main():
    try:
        # Load trades from packaged_trades.json
        with open('../../Order-Book-Matching-Engine/OrderMatchingEngine/packaged_trades.json') as f:
            trades = json.load(f)

        # Submit each trade
        for i, trade in enumerate(trades):
            print(f"\nSubmitting trade {i}...")
            receipt = submit_trade(trade)
            print(f"Trade {i} settled in tx: {receipt.transactionHash.hex()}")

    except Exception as e:
        print(f"Error in main: {str(e)}")
        print(f"Error type: {type(e)}")
        import traceback
        traceback.print_exc()
        raise

if __name__ == "__main__":
    main()
