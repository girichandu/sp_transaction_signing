//
//  SingpassTransactionSigning.swift
//  sp_transaction_signing
//
//  Created by B Giridhar on 6/7/25.
//

import UIKit

/// Main service class for Singpass Transaction Signing integration
class SingpassTransactionSigning {
    
    // MARK: - Properties
    
    private let config: SingpassConfig
    private let networkService: NetworkService
    private let backendService: DemoBackendService
    
    // MARK: - Initialization
    
    init(config: SingpassConfig) {
        self.config = config
        self.networkService = NetworkService(config: config)
        self.backendService = DemoBackendService(config: config)
    }
    
    // MARK: - Public Methods
    
    /// Start transaction signing process
    /// - Parameters:
    ///   - transactionInfo: Transaction information to be signed
    ///   - presentingViewController: View controller to present the signing interface
    ///   - completion: Completion handler with the signing result
    func startTransactionSigning(
        transactionInfo: TransactionInfo,
        from presentingViewController: UIViewController,
        completion: @escaping TransactionSigningCompletion
    ) {
        // Validate configuration
        guard isConfigurationValid() else {
            let result = TransactionSigningResult(
                success: false,
                signCode: nil,
                state: nil,
                error: .invalidConfiguration
            )
            completion(result)
            return
        }
        
        // Create and present the Singpass web view controller
        let webViewController = SingpassWebViewController(
            config: config,
            transactionInfo: transactionInfo
        ) { [weak self] result in
            self?.handleSigningResult(result, completion: completion)
        }
        
        let navigationController = UINavigationController(rootViewController: webViewController)
        navigationController.modalPresentationStyle = .pageSheet
        
        presentingViewController.present(navigationController, animated: true)
    }
    
    /// Verify transaction signature (backend operation)
    /// - Parameters:
    ///   - signCode: Sign code received from Singpass
    ///   - state: State parameter for validation
    ///   - nonce: Nonce parameter for validation
    /// - Returns: Verification result
    func verifyTransactionSignature(signCode: String, state: String, nonce: String) async throws -> Bool {
        return try await backendService.verifySignature(signCode: signCode, state: state, nonce: nonce)
    }
    
    // MARK: - Private Methods
    
    private func isConfigurationValid() -> Bool {
        print("🔍 Validating Singpass configuration...")

        // Check client ID
        guard !config.clientId.isEmpty else {
            print("❌ Configuration invalid: Client ID is empty")
            return false
        }

        if config.clientId == "YOUR_CLIENT_ID" || config.clientId == "DEMO_CLIENT_ID" {
            print("⚠️ Configuration warning: Using placeholder Client ID (\(config.clientId))")
            print("📝 Please replace with your actual Singpass Client ID")
            // Allow demo to continue but warn user
        }

        // Check redirect URI
        guard !config.redirectUri.isEmpty else {
            print("❌ Configuration invalid: Redirect URI is empty")
            return false
        }

        if config.redirectUri == "https://your-app.com/redirect" ||
           config.redirectUri == "https://demo-app.example.com/redirect" {
            print("⚠️ Configuration warning: Using placeholder Redirect URI (\(config.redirectUri))")
            print("📝 Please replace with your actual registered redirect URI")
            // Allow demo to continue but warn user
        }

        // Validate redirect URI format
        guard let url = URL(string: config.redirectUri),
              url.scheme == "https" else {
            print("❌ Configuration invalid: Redirect URI must be a valid HTTPS URL")
            return false
        }

        print("✅ Configuration validation passed")
        print("🔍 Client ID: \(config.clientId)")
        print("🔍 Redirect URI: \(config.redirectUri)")
        print("🔍 Environment: \(config.environment)")

        return true
    }
    
    private func handleSigningResult(_ result: TransactionSigningResult, completion: @escaping TransactionSigningCompletion) {
        if result.success, let signCode = result.signCode, let state = result.state {
            // In a real implementation, you would verify the signature with your backend
            Task {
                do {
                    // For demo purposes, we'll just validate that we have the required parameters
                    let isValid = try await verifyTransactionSignature(
                        signCode: signCode,
                        state: state,
                        nonce: "demo_nonce" // In real implementation, this should be stored and retrieved
                    )
                    
                    await MainActor.run {
                        let finalResult = TransactionSigningResult(
                            success: isValid,
                            signCode: signCode,
                            state: state,
                            error: isValid ? nil : .unknownError("Signature verification failed")
                        )
                        completion(finalResult)
                    }
                } catch {
                    await MainActor.run {
                        let finalResult = TransactionSigningResult(
                            success: false,
                            signCode: signCode,
                            state: state,
                            error: .networkError(error.localizedDescription)
                        )
                        completion(finalResult)
                    }
                }
            }
        } else {
            completion(result)
        }
    }
}

// MARK: - Convenience Factory

extension SingpassTransactionSigning {
    
    /// Create a Singpass Transaction Signing instance for staging environment
    static func staging(clientId: String, redirectUri: String) -> SingpassTransactionSigning {
        let config = SingpassConfig(
            clientId: clientId,
            redirectUri: redirectUri,
            environment: .staging
        )
        return SingpassTransactionSigning(config: config)
    }
    
    /// Create a Singpass Transaction Signing instance for production environment
    static func production(clientId: String, redirectUri: String) -> SingpassTransactionSigning {
        let config = SingpassConfig(
            clientId: clientId,
            redirectUri: redirectUri,
            environment: .production
        )
        return SingpassTransactionSigning(config: config)
    }
}

// MARK: - Demo Helper

extension SingpassTransactionSigning {
    
    /// Create a demo transaction for testing
    static func createDemoTransaction() -> TransactionInfo {
        let transactionId = "TXN_\(UUID().uuidString.prefix(8))"
        let instructions = "Transfer $100.00 from Account ***1234 to Account ***5678"
        let hash = TransactionInfo.generateHash(transactionId: transactionId, instructions: instructions)
        
        return TransactionInfo(
            transactionId: transactionId,
            instructions: instructions,
            hash: hash,
            userId: nil // Optional: can be set if user is known
        )
    }
}
