# 📱 E-Wallet App - Functionality Summary & Security Demo Guide

## 🎯 App Overview

**E-Wallet** is a secure mobile wallet application built with Flutter (frontend) and FastAPI (backend). The app allows users to manage their digital wallet, perform transactions, and view transaction history with comprehensive security measures.

---

## 📋 Core Functionality

### 1. **User Authentication & Registration**
- **Registration**: Users can create accounts with email, password, and full name
- **Email Verification**: OTP (One-Time Password) sent via email for account verification
- **Login**: Secure login with JWT token-based authentication
- **Password Management**: Change password functionality with validation
- **Session Management**: Auto-login with saved tokens, secure token storage

### 2. **Wallet Operations**
- **View Balance**: Display current wallet balance
- **Deposit**: Add funds to wallet (simulated transactions)
- **Withdraw**: Remove funds from wallet with balance validation
- **Transfer**: Send money to other users via email address
- **Transaction History**: View all past transactions with details (deposit, withdraw, transfer in/out)

### 3. **Advanced Features**
- **QR Code Transfers**: Generate QR codes for transfers and scan QR codes to auto-fill transfer details
- **Transaction Analytics**: Visual charts showing:
  - Pie chart by transaction type (Deposit, Withdraw, Transfer In/Out)
  - Bar chart by month showing transaction volume
- **Biometric Authentication**: Face ID / Fingerprint support for app access and transaction confirmation
- **Settings**: Configure biometric authentication, view security status

---

## 🔐 Security Features Implemented

### **Authentication Security**
1. **JWT Token Authentication**
   - Access tokens (30-minute expiration)
   - Refresh tokens (7-day expiration)
   - Secure token storage using `flutter_secure_storage` (Keychain/Keystore)

2. **Email OTP Verification**
   - Two-factor authentication during registration
   - OTP sent via Microsoft Graph API (email service)
   - OTP expiration (5 minutes)
   - Resend OTP functionality

3. **Password Security**
   - Bcrypt hashing (cost factor 12)
   - Password validation (min/max length)
   - Secure password change functionality

4. **Biometric Authentication**
   - Face ID / Fingerprint for app unlock
   - Biometric confirmation for sensitive transactions
   - Optional enable/disable in settings

### **Data Protection**
1. **AES-256 Encryption**
   - Transaction notes encrypted before database storage
   - Fernet encryption (symmetric encryption)
   - Encryption key stored securely in environment variables

2. **Secure Storage**
   - JWT tokens stored in secure storage (Keychain on iOS, Keystore on Android)
   - No sensitive data in plain text storage
   - Secure keyboard for PIN/sensitive input

### **Network Security**
1. **HTTPS Certificate Pinning**
   - Prevents MITM (Man-in-the-Middle) attacks
   - SHA-256 certificate fingerprint verification
   - Dio client with pinned certificates

2. **Rate Limiting**
   - API rate limiting (60 requests per minute)
   - Prevents brute force attacks
   - Prevents DDoS attacks

### **Transaction Security**
1. **OTP for Large Transfers**
   - Email OTP required for transfers ≥ ₫1,000,000
   - Additional verification layer for high-value transactions
   - Email notification for large transfers

2. **Auto Logout**
   - Automatic logout after 10 minutes of inactivity
   - Warning dialog before logout
   - Session timeout protection

3. **Transaction Validation**
   - Balance checks before withdrawals/transfers
   - Amount validation
   - Receiver validation

### **Device Security**
1. **Root/Jailbreak Detection**
   - Detects rooted Android devices
   - Detects jailbroken iOS devices
   - Security warnings for compromised devices

2. **App Integrity Verification**
   - Security check on app startup
   - Device security status monitoring

---

## 🎬 Security Demo Instructions

### **Prerequisites**
1. Ensure backend server is running:
   ```bash
   cd backend
   source .venv/bin/activate
   uvicorn app.main:app --reload
   ```

2. Ensure mobile app is running:
   ```bash
   cd mobile
   flutter run
   ```

3. Have at least 2 test accounts registered (for transfer demo)

---

### **Demo Flow: Step-by-Step**

#### **Part 1: Authentication Security Demo**

**1.1 Registration with OTP Verification**
1. Open the app
2. Navigate to **Register** screen
3. Enter test email, password, and full name
4. Click **Register**
5. **Show**: OTP email received (check email inbox)
6. Enter OTP code in verification screen
7. **Explain**: "OTP verification ensures only legitimate users can create accounts"

**1.2 Login & Token Storage**
1. Login with registered credentials
2. **Explain**: "JWT tokens are stored securely in device Keychain/Keystore"
3. **Show**: Open Security Demo screen (Menu → Security Demo)
4. Point to "Secure Token Storage" feature card

**1.3 Biometric Authentication**
1. Go to **Settings** → Enable Biometric Authentication
2. Close and reopen the app
3. **Show**: Biometric prompt appears
4. Authenticate with fingerprint/Face ID
5. **Explain**: "Biometric adds an extra layer of security for app access"

---

#### **Part 2: Data Protection Demo**

**2.1 AES Encryption**
1. Navigate to **Wallet** → **Transfer**
2. Enter receiver email and amount
3. Add a transaction note (e.g., "Payment for services")
4. Complete the transfer
5. **Explain**: "Transaction notes are encrypted with AES-256 before being stored in the database"
6. **Show**: Open backend database and show encrypted note field
   ```sql
   SELECT id, encrypted_note FROM transactions;
   ```
7. **Explain**: "Even if database is compromised, notes remain encrypted"

**2.2 Secure Storage**
1. In Security Demo screen, point to "Secure Token Storage" card
2. **Explain**: "Tokens are stored in secure storage, not in plain text files"
3. **Show**: Demonstrate that tokens persist after app restart (auto-login works)

---

#### **Part 3: Network Security Demo**

**3.1 HTTPS Certificate Pinning**
1. In Security Demo screen, point to "HTTPS Certificate Pinning" card
2. **Explain**: "Certificate pinning prevents MITM attacks by verifying server certificates"
3. **Show**: Open network inspector (if available) to show HTTPS connections
4. **Explain**: "If certificate doesn't match, connection is rejected"

**3.2 Rate Limiting**
1. Try to login with wrong password multiple times rapidly (5-10 times)
2. **Show**: Rate limit error message appears
3. **Explain**: "Rate limiting prevents brute force attacks by limiting request frequency"

---

#### **Part 4: Transaction Security Demo**

**4.1 OTP for Large Transfers**
1. Navigate to **Transfer** screen
2. Enter receiver email
3. Enter amount ≥ ₫1,000,000 (e.g., 1,500,000)
4. Click **Transfer**
5. **Show**: OTP request screen appears
6. **Explain**: "Large transfers require additional OTP verification for security"
7. Check email for OTP
8. Enter OTP and complete transfer
9. **Explain**: "This prevents unauthorized large transactions"

**4.2 Auto Logout (Inactivity)**
1. Login to the app
2. **Don't interact** with the app for 10 minutes
3. **Show**: Warning dialog appears: "You have been inactive for a while..."
4. **Explain**: "Auto logout protects your account if you leave the app unattended"
5. Click "Stay Logged In" to reset timer, or "Logout" to demonstrate logout

**4.3 Balance Validation**
1. Navigate to **Withdraw** screen
2. Enter amount greater than current balance
3. Click **Withdraw**
4. **Show**: Error message: "Insufficient funds"
5. **Explain**: "Server-side validation prevents invalid transactions"

---

#### **Part 5: Device Security Demo**

**5.1 Root/Jailbreak Detection**
1. Open **Security Demo** screen
2. **Show**: "Root/Jailbreak Detection" card
3. **Explain**: "App detects if device is compromised (rooted/jailbroken)"
4. **Show**: Status shows "✅ Secure" or "⚠️ Compromised"
5. **Explain**: "Compromised devices pose security risks, app warns users"

**5.2 Security Status Summary**
1. Scroll to bottom of Security Demo screen
2. **Show**: Security Summary section
3. **Explain**: "App implements multiple security layers:
   - 3 Authentication Layers (JWT, OTP, Biometric)
   - 2 Encryption Methods (AES-256, Bcrypt)
   - 6+ Security Checks
   - 10+ Active Protections"

---

#### **Part 6: Advanced Security Features Demo**

**6.1 Biometric Transaction Confirmation**
1. Enable biometric in Settings
2. Navigate to **Transfer** screen
3. Enter transfer details
4. Click **Transfer**
5. **Show**: Biometric prompt appears before transaction confirmation
6. **Explain**: "Biometric confirmation adds extra security for sensitive operations"

**6.2 Secure Keyboard**
1. Navigate to any password/PIN entry field
2. **Show**: Secure keyboard appears (no suggestions, no copy/paste)
3. **Explain**: "Secure keyboard prevents password leakage through keyboard logging"

**6.3 QR Code Security**
1. Navigate to **QR Transfer** screen
2. Generate QR code for a transfer
3. **Explain**: "QR codes contain encrypted transfer information"
4. Scan QR code with another device
5. **Show**: Transfer details auto-filled securely

---

### **Quick Demo Checklist**

Use this checklist to ensure you cover all security features:

- [ ] **Authentication**
  - [ ] Registration with OTP verification
  - [ ] Login with JWT tokens
  - [ ] Biometric authentication
  - [ ] Secure token storage

- [ ] **Data Protection**
  - [ ] AES-256 encryption (transaction notes)
  - [ ] Secure storage demonstration
  - [ ] Bcrypt password hashing

- [ ] **Network Security**
  - [ ] HTTPS certificate pinning
  - [ ] Rate limiting demonstration

- [ ] **Transaction Security**
  - [ ] OTP for large transfers
  - [ ] Auto logout (inactivity)
  - [ ] Balance validation

- [ ] **Device Security**
  - [ ] Root/jailbreak detection
  - [ ] Security status display

- [ ] **Advanced Features**
  - [ ] Biometric transaction confirmation
  - [ ] Secure keyboard
  - [ ] QR code security

---

## 📊 Security Features Summary Table

| Category | Feature | Status | Demo Method |
|----------|---------|--------|-------------|
| **Authentication** | JWT Tokens | ✅ Active | Show auto-login, token storage |
| | Email OTP | ✅ Active | Register new account |
| | Biometric Auth | ✅ Active | Enable in settings, test unlock |
| | Password Hashing | ✅ Active | Explain bcrypt, show in backend |
| **Data Protection** | AES-256 Encryption | ✅ Active | Show encrypted notes in DB |
| | Secure Storage | ✅ Active | Show Security Demo screen |
| **Network** | HTTPS Pinning | ✅ Active | Explain in Security Demo |
| | Rate Limiting | ✅ Active | Rapid failed login attempts |
| **Transaction** | Large Transfer OTP | ✅ Active | Transfer ≥ ₫1,000,000 |
| | Auto Logout | ✅ Active | Wait 10 minutes inactive |
| | Balance Validation | ✅ Active | Try to withdraw more than balance |
| **Device** | Root Detection | ✅ Active | Show Security Demo status |
| | Secure Keyboard | ✅ Active | Enter password field |

---

## 🎯 Key Talking Points for Demo

1. **Multi-Layer Security**: "Our app implements security at multiple levels - authentication, data protection, network security, and device security."

2. **Industry Standards**: "We use industry-standard encryption (AES-256), secure hashing (bcrypt), and token-based authentication (JWT)."

3. **User-Friendly Security**: "Security doesn't compromise usability - biometric authentication and auto-login make the app convenient while remaining secure."

4. **Proactive Protection**: "Features like auto-logout, rate limiting, and root detection proactively protect users from common attack vectors."

5. **Compliance Ready**: "The app follows security best practices suitable for financial applications."

---

## 📝 Notes for Presenters

- **Timing**: Full security demo takes approximately 15-20 minutes
- **Preparation**: Have test accounts ready, backend running, email access for OTP
- **Backup Plan**: If live demo fails, use Security Demo screen screenshots
- **Focus Areas**: Emphasize encryption, authentication, and transaction security
- **Questions**: Be prepared to explain technical details (AES-256, JWT, bcrypt)

---

*Last Updated: December 2024*





