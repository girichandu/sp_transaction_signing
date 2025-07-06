# Singpass Transaction Signing iOS Implementation

This iOS Swift application demonstrates how to integrate Singpass Transaction Signing into your mobile app using the official Singpass JavaScript SDK.

## Overview

Singpass Transaction Signing allows users to digitally sign transactions using their Singpass Mobile App. This implementation provides a complete iOS integration that:

1. **Retrieves Singpass transaction signing JavaScript (Singpass JS)**
2. **Initializes a transaction signing session via Singpass JS**
3. **Handles the complete signing workflow**

## Features

- ✅ Complete iOS Swift implementation
- ✅ WKWebView integration with Singpass JS
- ✅ JavaScript bridge for native-web communication
- ✅ JWT token creation and validation
- ✅ Session management and error handling
- ✅ Support for both staging and production environments
- ✅ Demo transaction creation and signing

## Architecture

### Core Components

1. **SingpassTransactionSigning** - Main service class for transaction signing
2. **SingpassWebViewController** - WebView controller for Singpass JS interface
3. **TransactionSigningModels** - Data models and configurations
4. **JWTHelper** - JWT creation and validation utilities
5. **NetworkService** - Network operations and API calls

### File Structure

```
sp_transaction_signing/
├── Models/
│   └── TransactionSigningModels.swift
├── Services/
│   ├── SingpassTransactionSigning.swift
│   ├── JWTHelper.swift
│   └── NetworkService.swift
├── ViewControllers/
│   ├── ViewController.swift
│   └── SingpassWebViewController.swift
└── Info.plist
```

## Implementation Details

### 1. Frontend Integration

The implementation uses WKWebView to load and interact with the Singpass JavaScript SDK:

```swift
// Initialize Singpass service
let singpassService = SingpassTransactionSigning.staging(
    clientId: "YOUR_CLIENT_ID",
    redirectUri: "https://your-app.com/redirect"
)

// Start transaction signing
singpassService.startTransactionSigning(
    transactionInfo: transaction,
    from: self
) { result in
    // Handle signing result
}
```

### 2. JavaScript Bridge

The app communicates with Singpass JS through WKWebView message handlers:

```javascript
// JavaScript to Swift communication
window.webkit.messageHandlers.singpassCallback.postMessage({
    code: signCode,
    state: state
});
```

### 3. JWT Token Creation

Transaction information is packaged into a signed JWT token:

```swift
struct JWTPayload: Codable {
    let txn_id: String
    let txn_instructions: String
    let txn_hash: String
    // ... other required fields
}
```

## Configuration

### 1. Singpass Configuration

Update the configuration in `ViewController.swift`:

```swift
private func setupSingpassService() {
    singpassService = SingpassTransactionSigning.staging(
        clientId: "YOUR_ACTUAL_CLIENT_ID",
        redirectUri: "https://your-app.com/redirect"
    )
}
```

### 2. Environment Setup

The implementation supports both staging and production environments:

- **Staging**: `https://static.staging.sign.singpass.gov.sg/static/ndi_txn_sign.js`
- **Production**: `https://static.app.sign.singpass.gov.sg/static/ndi_txn_sign.js`

### 3. Network Security

The `Info.plist` is configured to allow secure connections to Singpass domains:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>singpass.gov.sg</key>
        <dict>
            <key>NSIncludesSubdomains</key>
            <true/>
        </dict>
    </dict>
</dict>
```

## Usage

### Basic Transaction Signing

1. Create a transaction:
```swift
let transaction = TransactionInfo(
    transactionId: "TXN_12345",
    instructions: "Transfer $100.00 to Account ***5678",
    hash: TransactionInfo.generateHash(transactionId: "TXN_12345", instructions: "Transfer $100.00 to Account ***5678"),
    userId: nil
)
```

2. Start signing process:
```swift
singpassService.startTransactionSigning(
    transactionInfo: transaction,
    from: viewController
) { result in
    if result.success {
        print("Transaction signed successfully: \(result.signCode)")
    } else {
        print("Signing failed: \(result.error?.localizedDescription)")
    }
}
```

## Security Considerations

### Production Implementation

⚠️ **Important**: This demo includes simplified implementations for demonstration purposes. For production use:

1. **JWT Signing**: Must be done on your secure backend server
2. **Private Keys**: Never store private keys in the mobile app
3. **API Calls**: All sensitive operations should go through your backend
4. **Validation**: Implement proper signature validation on your backend

### Backend Requirements

Your backend must implement:

1. **JWT Creation**: Sign transaction JWTs with your private key
2. **Session Management**: Generate and validate state/nonce parameters
3. **Signature Verification**: Verify signatures with Singpass API
4. **JWKS Endpoint**: Provide public keys for Singpass validation

## Error Handling

The implementation includes comprehensive error handling:

```swift
enum TransactionSigningError: Error {
    case invalidConfiguration
    case jwtCreationFailed
    case webViewLoadFailed
    case sessionExpired
    case userCancelled
    case networkError(String)
    case unknownError(String)
}
```

## Testing

### Demo Mode

The app includes a demo mode for testing:

1. Run the app
2. Tap "Sign with Singpass"
3. The Singpass interface will load in a WebView
4. Follow the QR code scanning process

### Integration Testing

For full integration testing, you'll need:

1. Valid Singpass client credentials
2. Registered redirect URI
3. Proper backend implementation
4. Test Singpass account

## Dependencies

- iOS 13.0+
- Swift 5.0+
- WebKit framework
- CommonCrypto (for SHA256 hashing)

## References

- [Singpass Transaction Signing Documentation](https://docs.sign.singpass.gov.sg/for-relying-parties/api-documentation/transaction-signing)
- [Embedding Singpass JS](https://docs.sign.singpass.gov.sg/for-relying-parties/api-documentation/transaction-signing/embedding-singpass-js)
- [Init Transaction Signing](https://docs.sign.singpass.gov.sg/for-relying-parties/api-documentation/transaction-signing/init-transaction-signing)

## License

This project is for demonstration purposes. Please refer to Singpass documentation for official implementation guidelines.
