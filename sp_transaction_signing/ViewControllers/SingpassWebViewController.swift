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
        
        // Add message handlers for JavaScript communication
        configuration.userContentController.add(self, name: "singpassCallback")
        configuration.userContentController.add(self, name: "singpassError")
        
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
            
            <script src="\(config.environment.jsUrl)"></script>
            <script>
                async function initializeSingpass() {
                    try {
                        const transactionParamsSupplier = async () => {
                            return {
                                state: '\(sessionParams.state)',
                                nonce: '\(sessionParams.nonce)',
                                txnInfo: '\(sessionParams.txnInfo)'
                            };
                        };
                        
                        const onError = (errorId, message) => {
                            console.error('Singpass Error:', errorId, message);
                            window.webkit.messageHandlers.singpassError.postMessage({
                                errorId: errorId,
                                message: message
                            });
                        };
                        
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
                        
                        console.log('Singpass initialization result:', result);
                        
                        // Handle redirect by intercepting navigation
                        // The Singpass JS will redirect to the configured redirectUri
                        // We need to catch this and extract the code and state parameters
                        
                    } catch (error) {
                        console.error('Initialization error:', error);
                        document.getElementById('error-container').innerHTML = 
                            '<div class="error">Failed to initialize Singpass: ' + error.message + '</div>';
                    }
                }
                
                // Initialize when page loads
                window.addEventListener('load', initializeSingpass);
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
        loadingIndicator.stopAnimating()
        webView.isHidden = false
        statusLabel.isHidden = true
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleError(TransactionSigningError.webViewLoadFailed)
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
                handleSuccess(signCode: code, state: state)
            }
            
        case "singpassError":
            let errorId = body["errorId"] as? String
            let errorMessage = body["message"] as? String ?? "Unknown error"
            let error = TransactionSigningError.unknownError(errorMessage)
            handleError(error)
            
        default:
            break
        }
    }
}
