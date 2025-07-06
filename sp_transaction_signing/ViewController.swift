//
//  ViewController.swift
//  sp_transaction_signing
//
//  Created by B Giridhar on 6/7/25.
//

import UIKit

class ViewController: UIViewController {

    // MARK: - Properties

    private var singpassService: SingpassTransactionSigning!

    // UI Elements
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let transactionDetailsView = UIView()
    private let transactionIdLabel = UILabel()
    private let transactionInstructionsLabel = UILabel()
    private let signButton = UIButton(type: .system)
    private let resultLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSingpassService()
        setupUI()
        setupDemoTransaction()
    }

    // MARK: - Setup

    private func setupSingpassService() {
        // Configure for staging environment
        // Replace with your actual client ID and redirect URI
        singpassService = SingpassTransactionSigning.staging(
            clientId: "YOUR_CLIENT_ID", // Replace with your actual client ID
            redirectUri: "https://your-app.com/redirect" // Replace with your actual redirect URI
        )
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Singpass Transaction Signing"

        // Setup title label
        titleLabel.text = "Singpass Transaction Signing Demo"
        titleLabel.font = .boldSystemFont(ofSize: 24)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        // Setup description label
        descriptionLabel.text = "This demo shows how to integrate Singpass Transaction Signing in your iOS app."
        descriptionLabel.font = .systemFont(ofSize: 16)
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0
        descriptionLabel.textColor = .secondaryLabel

        // Setup transaction details view
        transactionDetailsView.backgroundColor = .secondarySystemBackground
        transactionDetailsView.layer.cornerRadius = 12
        transactionDetailsView.layer.borderWidth = 1
        transactionDetailsView.layer.borderColor = UIColor.separator.cgColor

        // Setup transaction labels
        transactionIdLabel.font = .monospacedSystemFont(ofSize: 14, weight: .medium)
        transactionIdLabel.numberOfLines = 0

        transactionInstructionsLabel.font = .systemFont(ofSize: 16)
        transactionInstructionsLabel.numberOfLines = 0

        // Setup sign button
        signButton.setTitle("Sign with Singpass", for: .normal)
        signButton.titleLabel?.font = .boldSystemFont(ofSize: 18)
        signButton.backgroundColor = .systemBlue
        signButton.setTitleColor(.white, for: .normal)
        signButton.layer.cornerRadius = 12
        signButton.addTarget(self, action: #selector(signButtonTapped), for: .touchUpInside)

        // Setup result label
        resultLabel.font = .systemFont(ofSize: 16)
        resultLabel.textAlignment = .center
        resultLabel.numberOfLines = 0
        resultLabel.isHidden = true

        // Setup activity indicator
        activityIndicator.hidesWhenStopped = true

        // Add subviews
        [titleLabel, descriptionLabel, transactionDetailsView, signButton, resultLabel, activityIndicator].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        [transactionIdLabel, transactionInstructionsLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            transactionDetailsView.addSubview($0)
        }

        setupConstraints()
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Title label
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            // Description label
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            descriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            // Transaction details view
            transactionDetailsView.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 30),
            transactionDetailsView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            transactionDetailsView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            // Transaction ID label
            transactionIdLabel.topAnchor.constraint(equalTo: transactionDetailsView.topAnchor, constant: 16),
            transactionIdLabel.leadingAnchor.constraint(equalTo: transactionDetailsView.leadingAnchor, constant: 16),
            transactionIdLabel.trailingAnchor.constraint(equalTo: transactionDetailsView.trailingAnchor, constant: -16),

            // Transaction instructions label
            transactionInstructionsLabel.topAnchor.constraint(equalTo: transactionIdLabel.bottomAnchor, constant: 12),
            transactionInstructionsLabel.leadingAnchor.constraint(equalTo: transactionDetailsView.leadingAnchor, constant: 16),
            transactionInstructionsLabel.trailingAnchor.constraint(equalTo: transactionDetailsView.trailingAnchor, constant: -16),
            transactionInstructionsLabel.bottomAnchor.constraint(equalTo: transactionDetailsView.bottomAnchor, constant: -16),

            // Sign button
            signButton.topAnchor.constraint(equalTo: transactionDetailsView.bottomAnchor, constant: 30),
            signButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            signButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            signButton.heightAnchor.constraint(equalToConstant: 50),

            // Activity indicator
            activityIndicator.centerXAnchor.constraint(equalTo: signButton.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: signButton.centerYAnchor),

            // Result label
            resultLabel.topAnchor.constraint(equalTo: signButton.bottomAnchor, constant: 20),
            resultLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            resultLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    private func setupDemoTransaction() {
        let transaction = SingpassTransactionSigning.createDemoTransaction()
        transactionIdLabel.text = "Transaction ID: \(transaction.transactionId)"
        transactionInstructionsLabel.text = "Instructions: \(transaction.instructions)"
    }

    // MARK: - Actions

    @objc private func signButtonTapped() {
        let transaction = SingpassTransactionSigning.createDemoTransaction()

        // Update UI to show loading state
        signButton.setTitle("", for: .normal)
        activityIndicator.startAnimating()
        signButton.isEnabled = false
        resultLabel.isHidden = true

        // Start transaction signing
        singpassService.startTransactionSigning(
            transactionInfo: transaction,
            from: self
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.handleSigningResult(result)
            }
        }
    }

    private func handleSigningResult(_ result: TransactionSigningResult) {
        // Reset button state
        signButton.setTitle("Sign with Singpass", for: .normal)
        activityIndicator.stopAnimating()
        signButton.isEnabled = true

        // Show result
        resultLabel.isHidden = false

        if result.success {
            resultLabel.text = "✅ Transaction signed successfully!\nSign Code: \(result.signCode ?? "N/A")"
            resultLabel.textColor = .systemGreen
        } else {
            let errorMessage = result.error?.localizedDescription ?? "Unknown error"
            resultLabel.text = "❌ Transaction signing failed:\n\(errorMessage)"
            resultLabel.textColor = .systemRed
        }
    }
}

