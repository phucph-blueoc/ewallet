import requests
import time
import sys

BASE_URL = "http://localhost:8000/api/v1"

def register_user(email, password, name):
    response = requests.post(f"{BASE_URL}/auth/register", json={
        "email": email,
        "password": password,
        "full_name": name
    })
    if response.status_code != 200:
        print(f"Registration failed for {email}: {response.text}")
        return None
    return response.json()

def login_user(email, password):
    response = requests.post(f"{BASE_URL}/auth/login", data={
        "username": email,
        "password": password
    })
    if response.status_code != 200:
        print(f"Login failed for {email}: {response.text}")
        return None
    return response.json()["access_token"]

def get_wallet(token):
    headers = {"Authorization": f"Bearer {token}"}
    response = requests.get(f"{BASE_URL}/wallets/me", headers=headers)
    if response.status_code != 200:
        print(f"Get wallet failed: {response.text}")
        return None
    return response.json()

def deposit(token, amount):
    headers = {"Authorization": f"Bearer {token}"}
    response = requests.post(f"{BASE_URL}/wallets/deposit", headers=headers, json={"amount": amount})
    if response.status_code != 200:
        print(f"Deposit failed: {response.text}")
        return None
    return response.json()

def withdraw(token, amount):
    headers = {"Authorization": f"Bearer {token}"}
    response = requests.post(f"{BASE_URL}/wallets/withdraw", headers=headers, json={"amount": amount})
    if response.status_code != 200:
        print(f"Withdraw failed: {response.text}")
        return None
    return response.json()

def transfer(token, receiver_email, amount, note="Test Transfer"):
    headers = {"Authorization": f"Bearer {token}"}
    response = requests.post(f"{BASE_URL}/wallets/transfer", headers=headers, json={
        "receiver_email": receiver_email,
        "amount": amount,
        "note": note
    })
    if response.status_code != 200:
        print(f"Transfer failed: {response.text}")
        return None
    return response.json()

def get_transactions(token):
    headers = {"Authorization": f"Bearer {token}"}
    response = requests.get(f"{BASE_URL}/wallets/transactions", headers=headers)
    if response.status_code != 200:
        print(f"Get transactions failed: {response.text}")
        return None
    return response.json()

def main():
    print("Starting Wallet Verification...")
    
    # 1. Register User A
    email_a = f"user_a_{int(time.time())}@example.com"
    print(f"Registering {email_a}...")
    user_a = register_user(email_a, "password123", "User A")
    if not user_a: sys.exit(1)
    
    # 2. Register User B
    email_b = f"user_b_{int(time.time())}@example.com"
    print(f"Registering {email_b}...")
    user_b = register_user(email_b, "password123", "User B")
    if not user_b: sys.exit(1)
    
    # 3. Login User A
    print("Logging in User A...")
    token_a = login_user(email_a, "password123")
    if not token_a: sys.exit(1)
    
    # 4. Login User B
    print("Logging in User B...")
    token_b = login_user(email_b, "password123")
    if not token_b: sys.exit(1)
    
    # 5. Check Initial Balance A
    wallet_a = get_wallet(token_a)
    print(f"User A Initial Balance: {wallet_a['balance']}")
    assert wallet_a['balance'] == 0.0
    
    # 6. Deposit to User A
    print("Depositing 1000 to User A...")
    wallet_a = deposit(token_a, 1000.0)
    print(f"User A Balance after deposit: {wallet_a['balance']}")
    assert wallet_a['balance'] == 1000.0
    
    # 7. Withdraw from User A
    print("Withdrawing 200 from User A...")
    wallet_a = withdraw(token_a, 200.0)
    print(f"User A Balance after withdraw: {wallet_a['balance']}")
    assert wallet_a['balance'] == 800.0
    
    # 8. Transfer from A to B
    print("Transferring 300 from A to B...")
    tx = transfer(token_a, email_b, 300.0, "Lunch money")
    print(f"Transfer successful. Tx ID: {tx['id']}")
    
    # 9. Check Balances
    wallet_a = get_wallet(token_a)
    wallet_b = get_wallet(token_b)
    print(f"User A Final Balance: {wallet_a['balance']}")
    print(f"User B Final Balance: {wallet_b['balance']}")
    assert wallet_a['balance'] == 500.0
    assert wallet_b['balance'] == 300.0
    
    # 10. Check Transactions for A
    print("Checking transactions for User A...")
    txs_a = get_transactions(token_a)
    print(f"User A has {len(txs_a)} transactions")
    # Should have: Deposit (1000), Withdraw (200), Transfer Out (300)
    assert len(txs_a) >= 3
    
    # 11. Check Transactions for B
    print("Checking transactions for User B...")
    txs_b = get_transactions(token_b)
    print(f"User B has {len(txs_b)} transactions")
    # Should have: Transfer In (300)
    assert len(txs_b) >= 1
    
    # Verify decrypted note
    transfer_tx = next((t for t in txs_b if t['type'] == 'transfer_in'), None)
    if transfer_tx:
        print(f"Decrypted note for B: {transfer_tx['note']}")
        assert transfer_tx['note'] == "Lunch money"
    
    print("Verification Successful!")

if __name__ == "__main__":
    main()
