//
//  JWTHelper.swift
//  sp_transaction_signing
//
//  Created by B Giridhar on 6/7/25.
//

import Foundation
import Security

/// Helper class for JWT creation and validation
class JWTHelper {
    
    // MARK: - Properties
    
    private let keyId: String
    private let privateKey: SecKey
    
    // MARK: - Initialization
    
    init(keyId: String, privateKey: SecKey) {
        self.keyId = keyId
        self.privateKey = privateKey
    }
    
    // MARK: - JWT Creation
    
    /// Create a signed JWT for transaction signing
    func createTransactionJWT(transactionInfo: TransactionInfo, issuer: String, audience: String) throws -> String {
        // Create header
        let header = JWTHeader(kid: keyId)
        let headerData = try JSONEncoder().encode(header)
        let headerBase64 = headerData.base64URLEncodedString()
        
        // Create payload
        let payload = JWTPayload(transactionInfo: transactionInfo, issuer: issuer, audience: audience)
        let payloadData = try JSONEncoder().encode(payload)
        let payloadBase64 = payloadData.base64URLEncodedString()
        
        // Create signature
        let signingInput = "\(headerBase64).\(payloadBase64)"
        let signature = try sign(data: signingInput.data(using: .utf8)!)
        let signatureBase64 = signature.base64URLEncodedString()
        
        return "\(signingInput).\(signatureBase64)"
    }
    
    // MARK: - Private Methods
    
    private func sign(data: Data) throws -> Data {
        var error: Unmanaged<CFError>?
        
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .ecdsaSignatureMessageX962SHA256,
            data as CFData,
            &error
        ) else {
            if let error = error?.takeRetainedValue() {
                throw TransactionSigningError.jwtCreationFailed
            }
            throw TransactionSigningError.jwtCreationFailed
        }
        
        return signature as Data
    }
    
    // MARK: - Key Generation (for demo purposes)
    
    /// Generate a new ECDSA key pair for demo purposes
    /// In production, you should use proper key management
    static func generateKeyPair() throws -> (privateKey: SecKey, publicKey: SecKey) {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: false
            ]
        ]
        
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw TransactionSigningError.jwtCreationFailed
        }
        
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw TransactionSigningError.jwtCreationFailed
        }
        
        return (privateKey, publicKey)
    }
    
    /// Get public key in PEM format for JWKS
    static func getPublicKeyPEM(publicKey: SecKey) throws -> String {
        var error: Unmanaged<CFError>?
        
        guard let keyData = SecKeyCopyExternalRepresentation(publicKey, &error) else {
            throw TransactionSigningError.jwtCreationFailed
        }
        
        let data = keyData as Data
        let base64 = data.base64EncodedString()
        
        // Format as PEM
        let pem = """
        -----BEGIN PUBLIC KEY-----
        \(base64.chunked(into: 64).joined(separator: "\n"))
        -----END PUBLIC KEY-----
        """
        
        return pem
    }
}

// MARK: - Extensions

extension Data {
    /// Base64URL encoding (RFC 4648)
    func base64URLEncodedString() -> String {
        return base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

extension String {
    /// Split string into chunks of specified size
    func chunked(into size: Int) -> [String] {
        return stride(from: 0, to: count, by: size).map {
            let start = index(startIndex, offsetBy: $0)
            let end = index(start, offsetBy: min(size, count - $0))
            return String(self[start..<end])
        }
    }
}

// MARK: - Demo JWT Helper

/// Demo implementation for testing purposes
class DemoJWTHelper {
    
    /// Create a demo JWT token for testing
    /// In production, this should be done on your backend server
    static func createDemoJWT(transactionInfo: TransactionInfo, clientId: String) -> String {
        let header = ["alg": "ES256", "typ": "JWT", "kid": "demo-key-1"]
        let payload = [
            "exp": Int(Date().timeIntervalSince1970) + 120,
            "iss": clientId,
            "aud": "https://stg-id.singpass.gov.sg/txn-signing-sessions",
            "txn_id": transactionInfo.transactionId,
            "txn_instructions": transactionInfo.instructions,
            "txn_hash": transactionInfo.hash,
            "iat": Int(Date().timeIntervalSince1970),
            "sub": transactionInfo.userId ?? ""
        ] as [String: Any]
        
        do {
            let headerData = try JSONSerialization.data(withJSONObject: header)
            let payloadData = try JSONSerialization.data(withJSONObject: payload)
            
            let headerBase64 = headerData.base64URLEncodedString()
            let payloadBase64 = payloadData.base64URLEncodedString()
            
            // For demo purposes, we'll use a dummy signature
            // In production, this must be properly signed with your private key
            let dummySignature = "demo_signature_replace_with_real_signature"
            
            return "\(headerBase64).\(payloadBase64).\(dummySignature)"
        } catch {
            return ""
        }
    }
}
