# Singpass Transaction Signing - QR Code Generation Troubleshooting Guide

## Common QR Code Generation Issues and Solutions

### 1. **QR Code Not Appearing**

#### Symptoms:
- Empty QR code container
- "Loading Singpass interface..." message persists
- No error messages displayed

#### Possible Causes & Solutions:

**A. Configuration Issues:**
```swift
// ❌ Incorrect (placeholder values)
singpassService = SingpassTransactionSigning.staging(
    clientId: "YOUR_CLIENT_ID",
    redirectUri: "https://your-app.com/redirect"
)

// ✅ Correct (actual values from Singpass)
singpassService = SingpassTransactionSigning.staging(
    clientId: "your_actual_client_id_from_singpass",
    redirectUri: "https://your-registered-domain.com/redirect"
)
```

**B. Network/SDK Loading Issues:**
- Check if the Singpass JavaScript SDK is loading properly
- Verify network connectivity
- Check console logs for JavaScript errors

**C. JWT Token Issues:**
- Ensure JWT token is being generated correctly
- Verify JWT format (should have 3 parts separated by dots)

### 2. **JavaScript SDK Loading Failures**

#### Symptoms:
- Error: "Singpass SDK failed to load"
- Console error: "window.NDI is undefined"

#### Solutions:

**A. Check Network Configuration:**
Ensure your `Info.plist` allows connections to Singpass domains:
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

**B. Verify Environment URLs:**
- Staging: `https://static.staging.sign.singpass.gov.sg/static/ndi_txn_sign.js`
- Production: `https://static.app.sign.singpass.gov.sg/static/ndi_txn_sign.js`

### 3. **Invalid Configuration Errors**

#### Symptoms:
- Error: "Invalid Singpass configuration"
- QR code generation fails immediately

#### Solutions:

**A. Client ID Issues:**
- Ensure you have a valid Client ID from Singpass
- Client ID should not be empty or placeholder values
- Contact Singpass support if you don't have a valid Client ID

**B. Redirect URI Issues:**
- Must be a valid HTTPS URL
- Must be registered with Singpass for your Client ID
- Should match exactly what's registered (including trailing slashes)

### 4. **JWT Creation Failures**

#### Symptoms:
- Error: "Failed to create JWT token"
- Console log: "JWT creation failed - empty token"

#### Solutions:

**A. Check JWT Helper:**
- Ensure `DemoJWTHelper.createDemoJWT()` is working correctly
- Verify transaction information is valid
- Check if private key generation is successful

**B. Transaction Data Validation:**
```swift
let transaction = TransactionInfo(
    transactionId: "TXN_123", // Should not be empty
    instructions: "Transfer $100", // Should not be empty
    hash: TransactionInfo.generateHash(...), // Should be valid SHA256
    userId: nil // Optional
)
```

### 5. **WebView Loading Issues**

#### Symptoms:
- WebView fails to load
- Error: "Failed to load Singpass web interface"

#### Solutions:

**A. Enable WebView Debugging:**
```swift
// Add to WebView configuration
configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
```

**B. Check WebView Delegate Methods:**
- Monitor `didFinish` and `didFail` navigation methods
- Check for network errors in delegate callbacks

## Debugging Steps

### 1. **Enable Debug Logging**
The updated implementation includes comprehensive debug logging. Check the Xcode console for:
- `🔍 [WebView Debug]` messages from JavaScript
- `✅` success indicators
- `❌` error indicators
- `⚠️` warning messages

### 2. **Verify Configuration**
```swift
// The app will now log configuration validation results
// Look for these messages in the console:
// "✅ Configuration validation passed"
// "⚠️ Configuration warning: Using placeholder Client ID"
```

### 3. **Check Network Requests**
Monitor network requests in Xcode's Network tab to ensure:
- Singpass JavaScript SDK is being downloaded successfully
- No CORS or network security issues

### 4. **Test JWT Generation**
```swift
// Run the included test to verify JWT generation
func testJWTTokenGeneration() {
    // This test validates JWT creation and format
}
```

## Environment-Specific Issues

### Staging Environment
- URL: `https://static.staging.sign.singpass.gov.sg/static/ndi_txn_sign.js`
- Use staging Client ID and redirect URI
- May have different validation rules

### Production Environment
- URL: `https://static.app.sign.singpass.gov.sg/static/ndi_txn_sign.js`
- Requires production Client ID and redirect URI
- Stricter validation and security requirements

## Getting Help

### 1. **Check Console Logs**
Always check the Xcode console for detailed error messages and debug information.

### 2. **Verify Singpass Documentation**
Ensure your implementation follows the latest Singpass Transaction Signing documentation.

### 3. **Contact Singpass Support**
If configuration issues persist, contact Singpass technical support with:
- Your Client ID
- Registered redirect URI
- Error messages from console logs
- Environment (staging/production)

## Quick Fixes Checklist

- [ ] Replace placeholder `clientId` and `redirectUri` with actual values
- [ ] Verify network connectivity and Info.plist configuration
- [ ] Check console logs for specific error messages
- [ ] Ensure JWT token generation is working
- [ ] Verify WebView is loading the Singpass SDK successfully
- [ ] Test with both staging and production environments
- [ ] Run the included unit tests to validate core functionality

## Recent Improvements

The codebase has been updated with:
- ✅ Enhanced error handling and debugging
- ✅ Better configuration validation
- ✅ Comprehensive console logging
- ✅ JavaScript SDK loading verification
- ✅ JWT token format validation
- ✅ WebView navigation monitoring
- ✅ Improved error messages and user feedback
