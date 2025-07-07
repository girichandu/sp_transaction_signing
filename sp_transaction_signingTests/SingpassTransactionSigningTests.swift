//
//  SingpassTransactionSigningTests.swift
//  sp_transaction_signingTests
//
//  Created by B Giridhar on 6/7/25.
//

import XCTest
@testable import sp_transaction_signing

class SingpassTransactionSigningTests: XCTestCase {
    
    var singpassService: SingpassTransactionSigning!
    var testConfig: SingpassConfig!
    
    override func setUpWithError() throws {
        testConfig = SingpassConfig(
            clientId: "TEST_CLIENT_ID",
            redirectUri: "https://test.example.com/redirect",
            environment: .staging
        )
        singpassService = SingpassTransactionSigning(config: testConfig)
    }
    
    override func tearDownWithError() throws {
        singpassService = nil
        testConfig = nil
    }
    
    // MARK: - Configuration Tests
    
    func testSingpassConfigCreation() {
        XCTAssertEqual(testConfig.clientId, "TEST_CLIENT_ID")
        XCTAssertEqual(testConfig.redirectUri, "https://test.example.com/redirect")
        XCTAssertEqual(testConfig.environment.jsUrl, "https://static.staging.sign.singpass.gov.sg/static/ndi_txn_sign.js")
    }
    
    func testEnvironmentUrls() {
        let stagingConfig = SingpassConfig(clientId: "test", redirectUri: "test", environment: .staging)
        let productionConfig = SingpassConfig(clientId: "test", redirectUri: "test", environment: .production)
        
        XCTAssertEqual(stagingConfig.environment.jsUrl, "https://static.staging.sign.singpass.gov.sg/static/ndi_txn_sign.js")
        XCTAssertEqual(productionConfig.environment.jsUrl, "https://static.app.sign.singpass.gov.sg/static/ndi_txn_sign.js")
        
        XCTAssertEqual(stagingConfig.environment.apiBaseUrl, "https://stg-id.singpass.gov.sg")
        XCTAssertEqual(productionConfig.environment.apiBaseUrl, "https://id.singpass.gov.sg")
    }
    
    // MARK: - Transaction Info Tests
    
    func testTransactionInfoCreation() {
        let transactionId = "TXN_12345"
        let instructions = "Transfer $100.00 to Account ***5678"
        let hash = TransactionInfo.generateHash(transactionId: transactionId, instructions: instructions)
        
        let transaction = TransactionInfo(
            transactionId: transactionId,
            instructions: instructions,
            hash: hash,
            userId: "test-user-id"
        )
        
        XCTAssertEqual(transaction.transactionId, transactionId)
        XCTAssertEqual(transaction.instructions, instructions)
        XCTAssertEqual(transaction.hash, hash)
        XCTAssertEqual(transaction.userId, "test-user-id")
    }
    
    func testTransactionHashGeneration() {
        let transactionId = "TXN_12345"
        let instructions = "Transfer $100.00"
        let expectedInput = "\(transactionId):\(instructions)"
        
        let hash = TransactionInfo.generateHash(transactionId: transactionId, instructions: instructions)
        
        XCTAssertFalse(hash.isEmpty)
        XCTAssertEqual(hash.count, 64) // SHA256 produces 64 character hex string
        
        // Test consistency
        let hash2 = TransactionInfo.generateHash(transactionId: transactionId, instructions: instructions)
        XCTAssertEqual(hash, hash2)
    }
    
    // MARK: - Demo Transaction Tests
    
    func testDemoTransactionCreation() {
        let demoTransaction = SingpassTransactionSigning.createDemoTransaction()
        
        XCTAssertTrue(demoTransaction.transactionId.hasPrefix("TXN_"))
        XCTAssertFalse(demoTransaction.instructions.isEmpty)
        XCTAssertFalse(demoTransaction.hash.isEmpty)
        XCTAssertEqual(demoTransaction.hash.count, 64)
        
        // Verify hash is correctly generated
        let expectedHash = TransactionInfo.generateHash(
            transactionId: demoTransaction.transactionId,
            instructions: demoTransaction.instructions
        )
        XCTAssertEqual(demoTransaction.hash, expectedHash)
    }
    
    // MARK: - JWT Helper Tests
    
    func testDemoJWTCreation() {
        let transaction = TransactionInfo(
            transactionId: "TXN_TEST",
            instructions: "Test transaction",
            hash: "test_hash",
            userId: "test_user"
        )
        
        let jwt = DemoJWTHelper.createDemoJWT(transactionInfo: transaction, clientId: "test_client")
        
        XCTAssertFalse(jwt.isEmpty)
        
        // JWT should have 3 parts separated by dots
        let parts = jwt.components(separatedBy: ".")
        XCTAssertEqual(parts.count, 3)
        
        // Verify we can decode the header and payload (base64URL encoded)
        let headerData = Data(base64Encoded: parts[0].base64URLDecoded())
        let payloadData = Data(base64Encoded: parts[1].base64URLDecoded())
        
        XCTAssertNotNil(headerData)
        XCTAssertNotNil(payloadData)
    }
    
    // MARK: - Network Service Tests
    
    func testNetworkServiceInitialization() {
        let networkService = NetworkService(config: testConfig)
        XCTAssertNotNil(networkService)
    }
    
    func testSessionParamsGeneration() async throws {
        let networkService = NetworkService(config: testConfig)
        let transaction = SingpassTransactionSigning.createDemoTransaction()
        
        let sessionParams = try await networkService.generateSessionParams(transactionInfo: transaction)
        
        XCTAssertFalse(sessionParams.state.isEmpty)
        XCTAssertFalse(sessionParams.nonce.isEmpty)
        XCTAssertFalse(sessionParams.txnInfo.isEmpty)
        
        // State and nonce should be different
        XCTAssertNotEqual(sessionParams.state, sessionParams.nonce)
    }
    
    // MARK: - Error Handling Tests
    
    func testTransactionSigningErrors() {
        let invalidConfigError = TransactionSigningError.invalidConfiguration
        let jwtError = TransactionSigningError.jwtCreationFailed
        let networkError = TransactionSigningError.networkError("Test error")
        
        XCTAssertEqual(invalidConfigError.localizedDescription, "Invalid Singpass configuration")
        XCTAssertEqual(jwtError.localizedDescription, "Failed to create JWT token")
        XCTAssertEqual(networkError.localizedDescription, "Network error: Test error")
    }
    
    // MARK: - Factory Methods Tests

    func testStagingFactory() {
        let stagingService = SingpassTransactionSigning.staging(
            clientId: "test_client",
            redirectUri: "https://test.com/redirect"
        )

        XCTAssertNotNil(stagingService)
    }

    // MARK: - Configuration Validation Tests

    func testConfigurationValidation() {
        // Test valid configuration
        let validConfig = SingpassConfig(
            clientId: "valid_client_id",
            redirectUri: "https://valid.example.com/redirect",
            environment: .staging
        )
        let validService = SingpassTransactionSigning(config: validConfig)
        XCTAssertNotNil(validService)

        // Test placeholder configurations (should still work but with warnings)
        let demoConfig = SingpassConfig(
            clientId: "DEMO_CLIENT_ID",
            redirectUri: "https://demo-app.example.com/redirect",
            environment: .staging
        )
        let demoService = SingpassTransactionSigning(config: demoConfig)
        XCTAssertNotNil(demoService)
    }

    func testJWTTokenGeneration() {
        let transaction = TransactionInfo(
            transactionId: "TEST_TXN_123",
            instructions: "Test transaction for QR code generation",
            hash: TransactionInfo.generateHash(transactionId: "TEST_TXN_123", instructions: "Test transaction for QR code generation"),
            userId: nil
        )

        let networkService = NetworkService(config: testConfig)

        let expectation = XCTestExpectation(description: "JWT generation should complete")

        Task {
            do {
                let sessionParams = try await networkService.generateSessionParams(transactionInfo: transaction)

                // Validate session parameters
                XCTAssertFalse(sessionParams.state.isEmpty, "State should not be empty")
                XCTAssertFalse(sessionParams.nonce.isEmpty, "Nonce should not be empty")
                XCTAssertFalse(sessionParams.txnInfo.isEmpty, "JWT token should not be empty")

                // Validate JWT format (should have 3 parts)
                let jwtParts = sessionParams.txnInfo.split(separator: ".")
                XCTAssertEqual(jwtParts.count, 3, "JWT should have 3 parts (header.payload.signature)")

                expectation.fulfill()
            } catch {
                XCTFail("JWT generation failed: \(error)")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)
    }
    
    func testProductionFactory() {
        let productionService = SingpassTransactionSigning.production(
            clientId: "test_client",
            redirectUri: "https://test.com/redirect"
        )
        
        XCTAssertNotNil(productionService)
    }
    
    // MARK: - Performance Tests
    
    func testTransactionHashPerformance() {
        let transactionId = "TXN_PERFORMANCE_TEST"
        let instructions = "This is a performance test for hash generation with a longer instruction text to simulate real-world usage"
        
        measure {
            for _ in 0..<1000 {
                _ = TransactionInfo.generateHash(transactionId: transactionId, instructions: instructions)
            }
        }
    }
}

// MARK: - Helper Extensions

extension String {
    func base64URLDecoded() -> String {
        var base64 = self
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Add padding if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        
        return base64
    }
}
