//
//  NetworkService.swift
//  sp_transaction_signing
//
//  Created by B Giridhar on 6/7/25.
//

import Foundation

/// Network service for handling API calls related to transaction signing
class NetworkService {
    
    // MARK: - Properties
    
    private let session: URLSession
    private let config: SingpassConfig
    
    // MARK: - Initialization
    
    init(config: SingpassConfig) {
        self.config = config
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - Session Management
    
    /// Generate session parameters for transaction signing
    func generateSessionParams(transactionInfo: TransactionInfo) async throws -> TransactionSessionParams {
        print("🔄 Generating session parameters...")

        // Generate unique state and nonce
        let state = generateSecureRandomString(length: 32)
        let nonce = generateSecureRandomString(length: 32)

        print("✅ Generated state: \(state.prefix(8))...")
        print("✅ Generated nonce: \(nonce.prefix(8))...")

        // Create JWT token
        // Note: In production, this should be done on your backend server
        print("🔄 Creating JWT token...")
        let txnInfo = DemoJWTHelper.createDemoJWT(transactionInfo: transactionInfo, clientId: config.clientId)

        guard !txnInfo.isEmpty else {
            print("❌ JWT creation failed - empty token")
            throw TransactionSigningError.jwtCreationFailed
        }

        // Validate JWT format (should have 3 parts separated by dots)
        let jwtParts = txnInfo.split(separator: ".")
        guard jwtParts.count == 3 else {
            print("❌ JWT validation failed - invalid format (expected 3 parts, got \(jwtParts.count))")
            throw TransactionSigningError.jwtCreationFailed
        }

        print("✅ JWT token created successfully (length: \(txnInfo.count))")
        print("🔍 JWT preview: \(txnInfo.prefix(50))...")

        let sessionParams = TransactionSessionParams(state: state, nonce: nonce, txnInfo: txnInfo)
        print("✅ Session parameters generated successfully")

        return sessionParams
    }
    
    // MARK: - Transaction Signature Exchange
    
    /// Exchange sign code for transaction signature
    func exchangeTransactionSignature(signCode: String, nonce: String) async throws -> TransactionSignatureResponse {
        let url = URL(string: "\(config.environment.apiBaseUrl)/txn-signatures")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = TransactionSignatureRequest(
            code: signCode,
            clientId: config.clientId,
            nonce: nonce
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TransactionSigningError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw TransactionSigningError.networkError("HTTP \(httpResponse.statusCode)")
        }
        
        return try JSONDecoder().decode(TransactionSignatureResponse.self, from: data)
    }
    
    // MARK: - Helper Methods
    
    private func generateSecureRandomString(length: Int) -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
        return String((0..<length).compactMap { _ in characters.randomElement() })
    }
}

// MARK: - Request/Response Models

struct TransactionSignatureRequest: Codable {
    let code: String
    let clientId: String
    let nonce: String
    
    enum CodingKeys: String, CodingKey {
        case code
        case clientId = "client_id"
        case nonce
    }
}

struct TransactionSignatureResponse: Codable {
    let signature: String
    let algorithm: String
    let timestamp: String
    let transactionId: String
    
    enum CodingKeys: String, CodingKey {
        case signature
        case algorithm
        case timestamp
        case transactionId = "transaction_id"
    }
}

// MARK: - Demo Backend Service

/// Demo backend service for testing purposes
/// In production, these operations should be performed on your secure backend
class DemoBackendService {
    
    private let config: SingpassConfig
    
    init(config: SingpassConfig) {
        self.config = config
    }
    
    /// Simulate backend session initialization
    func initializeSession(transactionInfo: TransactionInfo) async throws -> TransactionSessionParams {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        let state = generateSessionState()
        let nonce = generateSessionNonce()
        let txnInfo = createSignedJWT(transactionInfo: transactionInfo)
        
        return TransactionSessionParams(state: state, nonce: nonce, txnInfo: txnInfo)
    }
    
    /// Simulate backend signature verification
    func verifySignature(signCode: String, state: String, nonce: String) async throws -> Bool {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // In production, verify the signature with Singpass API
        // For demo, we'll just return true if we have valid parameters
        return !signCode.isEmpty && !state.isEmpty && !nonce.isEmpty
    }
    
    // MARK: - Private Methods
    
    private func generateSessionState() -> String {
        return "demo_state_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16))"
    }
    
    private func generateSessionNonce() -> String {
        return UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }
    
    private func createSignedJWT(transactionInfo: TransactionInfo) -> String {
        // In production, this should create a properly signed JWT
        return DemoJWTHelper.createDemoJWT(transactionInfo: transactionInfo, clientId: config.clientId)
    }
}
