# 🔐 Security Demo - Quick Reference Guide

## ⚡ Quick Demo Flow (10 minutes)

### 1. Authentication (2 min)
- **Register** → Show OTP email → Verify
- **Login** → Show auto-login works
- **Security Demo Screen** → Point to JWT & Secure Storage cards

### 2. Encryption (2 min)
- **Transfer** → Add note → Complete
- **Backend DB** → Show encrypted note field
- **Explain**: AES-256 encryption protects sensitive data

### 3. Transaction Security (3 min)
- **Large Transfer** (≥ ₫1M) → Show OTP requirement
- **Withdraw** more than balance → Show validation error
- **Wait 10 min** → Show auto-logout (or explain it)

### 4. Device Security (2 min)
- **Security Demo Screen** → Show all security cards
- **Root Detection** → Show status
- **Biometric** → Enable and test

### 5. Summary (1 min)
- **Security Demo Screen** → Scroll to summary
- **Highlight**: 3 auth layers, 2 encryption methods, 10+ protections

---

## 🎯 Key Features to Highlight

| Feature | How to Demo | Key Point |
|---------|-------------|-----------|
| **JWT Tokens** | Auto-login after restart | Secure token storage |
| **OTP Verification** | Register new account | Two-factor authentication |
| **AES Encryption** | Transfer with note → Check DB | Data encrypted at rest |
| **Biometric** | Enable in Settings → Test | Convenient security |
| **Large Transfer OTP** | Transfer ≥ ₫1M | Extra verification layer |
| **Auto Logout** | Wait 10 min or explain | Session timeout protection |
| **Rate Limiting** | Rapid failed logins | Prevents brute force |
| **Root Detection** | Security Demo screen | Device security check |

---

## 📱 Navigation Paths

- **Security Demo**: Wallet Home → Menu (⋮) → Security Demo
- **Settings**: Wallet Home → Menu (⋮) → Settings
- **Transfer**: Wallet Home → Transfer button
- **Transaction History**: Wallet Home → History button

---

## 💬 Key Phrases

- "Multi-layer security architecture"
- "Industry-standard encryption (AES-256)"
- "Secure token storage in device Keychain/Keystore"
- "Proactive protection against common attacks"
- "User-friendly security without compromising convenience"

---

## ⚠️ Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| OTP not received | Check email spam, verify SMTP config |
| Backend not running | `cd backend && uvicorn app.main:app --reload` |
| Token expired | Re-login, explain 30-min expiration |
| Biometric not working | Check device support, enable in Settings |

---

*Quick reference for live demos*





