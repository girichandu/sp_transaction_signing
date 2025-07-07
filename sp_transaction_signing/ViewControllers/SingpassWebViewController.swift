//
//  SingpassWebViewController.swift
//  sp_transaction_signing
//
//  Created by B Giridhar on 6/7/25.
//

import UIKit
import WebKit

/// View controller for displaying Singpass transaction signing interface
class SingpassWebViewController: UIViewController {
    
    // MARK: - Properties
    
    private var webView: WKWebView!
    private let config: SingpassConfig
    private let transactionInfo: TransactionInfo
    private var completion: TransactionSigningCompletion?
    private var sessionParams: TransactionSessionParams?
    
    // UI Elements
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    private let statusLabel = UILabel()
    private let cancelButton = UIButton(type: .system)
    
    // MARK: - Initialization
    
    init(config: SingpassConfig, transactionInfo: TransactionInfo, completion: @escaping TransactionSigningCompletion) {
        self.config = config
        self.transactionInfo = transactionInfo
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupWebView()
        initializeTransactionSigning()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Singpass Transaction Signing"
        
        // Setup navigation
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )
        
        // Setup loading indicator
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        view.addSubview(loadingIndicator)
        
        // Setup status label
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.text = "Initializing Singpass..."
        view.addSubview(statusLabel)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -50),
            
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: loadingIndicator.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
        
        loadingIndicator.startAnimating()
    }
    
    private func setupWebView() {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = WKUserContentController()

        // Enable debugging
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

        // Add message handlers for JavaScript communication
        configuration.userContentController.add(self, name: "singpassCallback")
        configuration.userContentController.add(self, name: "singpassError")
        configuration.userContentController.add(self, name: "debugLog") // Add debug logging

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.isHidden = true

        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - Transaction Signing
    
    private func initializeTransactionSigning() {
        Task {
            do {
                // Generate session parameters
                let networkService = NetworkService(config: config)
                sessionParams = try await networkService.generateSessionParams(transactionInfo: transactionInfo)
                
                await MainActor.run {
                    loadSingpassInterface()
                }
            } catch {
                await MainActor.run {
                    handleError(error)
                }
            }
        }
    }
    
    private func loadSingpassInterface() {
        guard let sessionParams = sessionParams else {
            handleError(TransactionSigningError.invalidConfiguration)
            return
        }
        
        let html = createSingpassHTML(sessionParams: sessionParams)
        webView.loadHTMLString(html, baseURL: URL(string: config.environment.apiBaseUrl))
        
        statusLabel.text = "Loading Singpass interface..."
    }
    
    private func createSingpassHTML(sessionParams: TransactionSessionParams) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Singpass Transaction Signing</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    margin: 0;
                    padding: 20px;
                    background-color: #f5f5f5;
                }
                .container {
                    max-width: 400px;
                    margin: 0 auto;
                    background: white;
                    border-radius: 12px;
                    padding: 20px;
                    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
                }
                .transaction-info {
                    margin-bottom: 20px;
                    padding: 15px;
                    background-color: #f8f9fa;
                    border-radius: 8px;
                }
                .transaction-info h3 {
                    margin: 0 0 10px 0;
                    color: #333;
                }
                .transaction-info p {
                    margin: 5px 0;
                    color: #666;
                }
                #singpass-qr {
                    margin: 20px auto;
                    text-align: center;
                }
                .error {
                    color: #dc3545;
                    background-color: #f8d7da;
                    border: 1px solid #f5c6cb;
                    border-radius: 4px;
                    padding: 10px;
                    margin: 10px 0;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="transaction-info">
                    <h3>Transaction Details</h3>
                    <p><strong>ID:</strong> \(transactionInfo.transactionId)</p>
                    <p><strong>Instructions:</strong> \(transactionInfo.instructions)</p>
                </div>
                <div id="singpass-qr"></div>
                <div id="error-container"></div>
            </div>
            
            <script>
                // Debug logging function
                function debugLog(message) {
                    console.log('[DEBUG]', message);
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.debugLog) {
                        window.webkit.messageHandlers.debugLog.postMessage({
                            message: message,
                            timestamp: new Date().toISOString()
                        });
                    }
                }

                // Check if script loaded successfully
                function checkScriptLoaded() {
                    debugLog('Checking if Singpass SDK is loaded...');
                    if (typeof window.NDI === 'undefined') {
                        debugLog('ERROR: window.NDI is undefined - Singpass SDK not loaded');
                        document.getElementById('error-container').innerHTML =
                            '<div class="error">Singpass SDK failed to load. Please check your network connection.</div>';
                        return false;
                    }
                    debugLog('SUCCESS: Singpass SDK loaded successfully');
                    return true;
                }

                async function initializeSingpass() {
                    debugLog('Starting Singpass initialization...');

                    try {
                        // Wait a bit for the script to load
                        await new Promise(resolve => setTimeout(resolve, 1000));

                        if (!checkScriptLoaded()) {
                            return;
                        }

                        debugLog('Creating transaction params supplier...');
                        const transactionParamsSupplier = async () => {
                            const params = {
                                state: '\(sessionParams.state)',
                                nonce: '\(sessionParams.nonce)',
                                txnInfo: '\(sessionParams.txnInfo)'
                            };
                            debugLog('Transaction params: ' + JSON.stringify({
                                state: params.state.substring(0, 8) + '...',
                                nonce: params.nonce.substring(0, 8) + '...',
                                txnInfo: params.txnInfo.substring(0, 50) + '...'
                            }));
                            return params;
                        };

                        debugLog('Setting up error handler...');
                        const onError = (errorId, message) => {
                            const errorMsg = 'Singpass Error - ID: ' + errorId + ', Message: ' + message;
                            console.error(errorMsg);
                            debugLog('ERROR: ' + errorMsg);

                            document.getElementById('error-container').innerHTML =
                                '<div class="error"><strong>QR Code Generation Failed</strong><br/>' +
                                'Error ID: ' + (errorId || 'Unknown') + '<br/>' +
                                'Message: ' + (message || 'Unknown error') + '</div>';

                            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.singpassError) {
                                window.webkit.messageHandlers.singpassError.postMessage({
                                    errorId: errorId,
                                    message: message
                                });
                            }
                        };

                        debugLog('Initializing Singpass transaction signing...');
                        debugLog('Client ID: \(config.clientId)');
                        debugLog('Redirect URI: \(config.redirectUri)');

                        const result = window.NDI.initTxnSigning(
                            'singpass-qr',
                            {
                                clientId: '\(config.clientId)',
                                redirectUri: '\(config.redirectUri)'
                            },
                            transactionParamsSupplier,
                            onError,
                            {
                                renderDownloadLink: true
                            }
                        );

                        debugLog('Singpass initialization result: ' + JSON.stringify(result));

                        if (result && result.status === 'SUCCESS') {
                            debugLog('QR code should be generated successfully');
                        } else {
                            debugLog('QR code generation may have failed - result: ' + JSON.stringify(result));
                        }

                    } catch (error) {
                        const errorMsg = 'Initialization error: ' + error.message;
                        console.error(errorMsg);
                        debugLog('FATAL ERROR: ' + errorMsg);

                        document.getElementById('error-container').innerHTML =
                            '<div class="error"><strong>Initialization Failed</strong><br/>' +
                            'Error: ' + error.message + '<br/>' +
                            'Please check the console for more details.</div>';
                    }
                }

                // Load the Singpass SDK
                function loadSingpassSDK() {
                    debugLog('Loading Singpass SDK from: \(config.environment.jsUrl)');

                    const script = document.createElement('script');
                    script.src = '\(config.environment.jsUrl)';
                    script.onload = function() {
                        debugLog('Singpass SDK script loaded successfully');
                        initializeSingpass();
                    };
                    script.onerror = function() {
                        debugLog('ERROR: Failed to load Singpass SDK script');
                        document.getElementById('error-container').innerHTML =
                            '<div class="error"><strong>SDK Loading Failed</strong><br/>' +
                            'Could not load Singpass SDK from: \(config.environment.jsUrl)<br/>' +
                            'Please check your network connection and configuration.</div>';
                    };
                    document.head.appendChild(script);
                }

                // Initialize when page loads
                window.addEventListener('load', function() {
                    debugLog('Page loaded, starting SDK loading...');
                    loadSingpassSDK();
                });
            </script>
        </body>
        </html>
        """
    }
    
    // MARK: - Actions
    
    @objc private func cancelTapped() {
        // Cancel the transaction signing session
        webView.evaluateJavaScript("window.NDI && window.NDI.cancelTxnSigningSession && window.NDI.cancelTxnSigningSession();")
        
        let result = TransactionSigningResult(
            success: false,
            signCode: nil,
            state: nil,
            error: .userCancelled
        )
        completion?(result)
        dismiss(animated: true)
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: Error) {
        loadingIndicator.stopAnimating()
        
        let transactionError: TransactionSigningError
        if let txnError = error as? TransactionSigningError {
            transactionError = txnError
        } else {
            transactionError = .unknownError(error.localizedDescription)
        }
        
        statusLabel.text = transactionError.localizedDescription
        
        let result = TransactionSigningResult(
            success: false,
            signCode: nil,
            state: nil,
            error: transactionError
        )
        completion?(result)
    }
    
    private func handleSuccess(signCode: String, state: String) {
        let result = TransactionSigningResult(
            success: true,
            signCode: signCode,
            state: state,
            error: nil
        )
        completion?(result)
        dismiss(animated: true)
    }
}

// MARK: - WKNavigationDelegate

extension SingpassWebViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("✅ WebView finished loading")
        loadingIndicator.stopAnimating()
        webView.isHidden = false
        statusLabel.isHidden = true

        // Check if the page loaded successfully by evaluating some JavaScript
        webView.evaluateJavaScript("document.readyState") { result, error in
            if let error = error {
                print("❌ WebView JavaScript evaluation error: \(error)")
            } else {
                print("✅ WebView ready state: \(result ?? "unknown")")
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("❌ WebView navigation failed: \(error.localizedDescription)")
        handleError(TransactionSigningError.webViewLoadFailed)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("❌ WebView provisional navigation failed: \(error.localizedDescription)")
        handleError(TransactionSigningError.webViewLoadFailed)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        print("🔍 WebView navigation to: \(url.absoluteString)")

        // Check if this is a redirect to our redirect URI
        if url.absoluteString.hasPrefix(config.redirectUri) {
            print("✅ Detected redirect to configured URI: \(config.redirectUri)")

            // Extract code and state from URL parameters
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let queryItems = components.queryItems {

                var code: String?
                var state: String?

                for item in queryItems {
                    if item.name == "code" {
                        code = item.value
                    } else if item.name == "state" {
                        state = item.value
                    }
                }

                if let code = code, let state = state {
                    print("✅ Extracted code and state from redirect")
                    handleSuccess(signCode: code, state: state)
                } else {
                    print("❌ Failed to extract code or state from redirect URL")
                    handleError(TransactionSigningError.unknownError("Invalid redirect parameters"))
                }
            }

            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }
}

// MARK: - WKScriptMessageHandler

extension SingpassWebViewController: WKScriptMessageHandler {

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else { return }

        switch message.name {
        case "singpassCallback":
            if let code = body["code"] as? String,
               let state = body["state"] as? String {
                print("✅ Singpass callback received - Code: \(code.prefix(8))..., State: \(state.prefix(8))...")
                handleSuccess(signCode: code, state: state)
            }

        case "singpassError":
            let errorId = body["errorId"] as? String ?? "UNKNOWN"
            let errorMessage = body["message"] as? String ?? "Unknown error"
            print("❌ Singpass error - ID: \(errorId), Message: \(errorMessage)")

            // Create more specific error based on error ID
            let error: TransactionSigningError
            if errorId.contains("INVALID_CLIENT") || errorId.contains("CLIENT") {
                error = .invalidConfiguration
            } else if errorId.contains("JWT") || errorId.contains("TOKEN") {
                error = .jwtCreationFailed
            } else if errorId.contains("NETWORK") || errorId.contains("CONNECTION") {
                error = .networkError(errorMessage)
            } else {
                error = .unknownError("[\(errorId)] \(errorMessage)")
            }

            handleError(error)

        case "debugLog":
            if let logMessage = body["message"] as? String,
               let timestamp = body["timestamp"] as? String {
                print("🔍 [WebView Debug] \(timestamp): \(logMessage)")
            }

        default:
            break
        }
    }
}
