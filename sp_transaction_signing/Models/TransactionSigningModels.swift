//
//  TransactionSigningModels.swift
//  sp_transaction_signing
//
//  Created by B Giridhar on 6/7/25.
//

import Foundation
import CryptoKit
import CommonCrypto

// MARK: - Transaction Signing Models

/// Configuration for Singpass Transaction Signing
struct SingpassConfig {
    let clientId: String
    let redirectUri: String
    let environment: Environment
    
    enum Environment {
        case staging
        case production
        
        var jsUrl: String {
            switch self {
            case .staging:
                return "https://static.staging.sign.singpass.gov.sg/static/ndi_txn_sign.js"
            case .production:
                return "https://static.app.sign.singpass.gov.sg/static/ndi_txn_sign.js"
            }
        }
        
        var apiBaseUrl: String {
            switch self {
            case .staging:
                return "https://stg-id.singpass.gov.sg"
            case .production:
                return "https://id.singpass.gov.sg"
            }
        }
    }
}

/// Transaction information for signing
struct TransactionInfo {
    let transactionId: String
    let instructions: String
    let hash: String
    let userId: String?
    
    /// Generate SHA256 hash of transaction ID and instructions
    static func generateHash(transactionId: String, instructions: String) -> String {
        let combined = "\(transactionId):\(instructions)"
        return combined.sha256()
    }
}

/// Session parameters for transaction signing
struct TransactionSessionParams {
    let state: String
    let nonce: String
    let txnInfo: String // JWT token
}

/// Response from transaction signing initialization
struct TransactionSigningResponse {
    let status: Status
    let errorId: String?
    let message: String?
    
    enum Status: String {
        case successful = "SUCCESSFUL"
        case failed = "FAILED"
        case noOp = "NO_OP"
    }
}

/// Error types for transaction signing
enum TransactionSigningError: Error, LocalizedError {
    case invalidConfiguration
    case jwtCreationFailed
    case webViewLoadFailed
    case sessionExpired
    case userCancelled
    case networkError(String)
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Invalid Singpass configuration"
        case .jwtCreationFailed:
            return "Failed to create JWT token"
        case .webViewLoadFailed:
            return "Failed to load Singpass web interface"
        case .sessionExpired:
            return "Transaction signing session expired"
        case .userCancelled:
            return "Transaction signing was cancelled by user"
        case .networkError(let message):
            return "Network error: \(message)"
        case .unknownError(let message):
            return "Unknown error: \(message)"
        }
    }
}

/// JWT Header for transaction signing
struct JWTHeader: Codable {
    let alg: String = "ES256"
    let typ: String = "JWT"
    let kid: String
}

/// JWT Payload for transaction signing
struct JWTPayload: Codable {
    let exp: Int
    let iss: String
    let aud: String
    let txn_id: String
    let txn_instructions: String
    let txn_hash: String
    let iat: Int
    let sub: String?
    
    init(transactionInfo: TransactionInfo, issuer: String, audience: String, expirationTime: TimeInterval = 120) {
        let now = Int(Date().timeIntervalSince1970)
        self.iat = now
        self.exp = now + Int(expirationTime)
        self.iss = issuer
        self.aud = audience
        self.txn_id = transactionInfo.transactionId
        self.txn_instructions = transactionInfo.instructions
        self.txn_hash = transactionInfo.hash
        self.sub = transactionInfo.userId
    }
}

/// Transaction signing result
struct TransactionSigningResult {
    let success: Bool
    let signCode: String?
    let state: String?
    let error: TransactionSigningError?
}

/// Callback types for transaction signing
typealias TransactionSigningCompletion = (TransactionSigningResult) -> Void
typealias TransactionErrorCallback = (String?, String) -> Void

// MARK: - Extensions

extension String {
    /// Generate SHA256 hash of the string
    func sha256() -> String {
        guard let data = self.data(using: .utf8) else { return "" }

        if #available(iOS 13.0, *) {
            // Use CryptoKit for iOS 13+
            let digest = SHA256.hash(data: data)
            return digest.compactMap { String(format: "%02x", $0) }.joined()
        } else {
            // Fallback to CommonCrypto for older iOS versions
            var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            data.withUnsafeBytes {
                _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
            }
            return hash.compactMap { String(format: "%02x", $0) }.joined()
        }
    }
}


