//
//  MobileBrokerSignInSheet.swift
//
//  Created for OpenClaw mobile authentication
//

import SwiftUI

/// SwiftUI view for mobile broker sign-in using GitHub Device Flow
public struct MobileBrokerSignInSheet: View {
    // MARK: - State

    @StateObject private var viewModel: ViewModel

    // MARK: - Initialization

    /// Initialize with a view model
    /// - Parameter viewModel: The view model for this sheet
    public init(viewModel: ViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    // MARK: - View

    public var body: some View {
        VStack(spacing: 0) {
            // Header with branded typography
            VStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 48))
                    .foregroundColor(OpenClawBrand.accent)
                    .accessibilityLabel("Security")

                Text("Sign In with GitHub")
                    .font(OpenClawType.title2)
                    .fontWeight(.semibold)

                Text("Complete the sign-in on your device")
                    .font(OpenClawType.subhead)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 24)
            .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 24) {
                    // User Code Display
                    self.userCodeSection

                    // Expiration countdown
                    self.expirationSection

                    // Verification URI
                    self.verificationURISection

                    // Status
                    self.statusSection

                    // Progress indicator
                    if self.viewModel.isPolling {
                        self.progressIndicator
                    }

                    // Error state
                    self.errorSection

                    // Success state
                    self.successSection

                    Spacer()
                        .frame(height: 24)
                }
                .padding(.horizontal, 24)
            }
        }
        .onAppear {
            self.viewModel.startDeviceFlow()
        }
        .onDisappear {
            self.viewModel.stopPolling()
        }
    }

    // MARK: - Subviews

    private var userCodeSection: some View {
        VStack(spacing: 12) {
            Text("Enter this code on GitHub:")
                .font(OpenClawType.headline)

            // User code in a styled box with branded typography
            Text(self.viewModel.userCode ?? "...")
                .font(OpenClawType.title1)
                .fontWeight(.bold)
                .monospacedDigit()
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5)))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray3), lineWidth: 1))

            // Copy button with branded typography
            Button(action: self.viewModel.copyUserCode) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.doc")
                    Text("Copy Code")
                        .font(OpenClawType.callout)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(OpenClawBrand.accent)
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(self.viewModel.userCode == nil)
        }
    }

    @ViewBuilder
    private var expirationSection: some View {
        if let expiresAt = viewModel.expiresAt {
            VStack(spacing: 4) {
                Text("Code expires in:")
                    .font(OpenClawType.footnote)
                    .foregroundColor(.secondary)

                Text(self.viewModel.timeRemaining)
                    .font(OpenClawType.headline)
                    .foregroundColor(self.viewModel.timeRemainingColor)
            }
        }
    }

    private var verificationURISection: some View {
        VStack(spacing: 8) {
            Text("Then visit:")
                .font(OpenClawType.footnote)
                .foregroundColor(.secondary)

            if let uri = viewModel.verificationURI {
                Link(
                    destination: uri,
                    label: {
                        Text(uri.absoluteString)
                            .font(OpenClawType.headline)
                            .foregroundColor(OpenClawBrand.accent)
                            .lineLimit(1)
                    })
            } else {
                Text("...")
                    .font(OpenClawType.headline)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if !self.viewModel.statusMessage.isEmpty {
            Text(self.viewModel.statusMessage)
                .font(OpenClawType.body)
                .foregroundColor(self.viewModel.statusMessageColor)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var progressIndicator: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: OpenClawBrand.accent))
            .padding(.vertical, 8)
    }

    @ViewBuilder
    private var errorSection: some View {
        if let error = viewModel.error {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 24))
                        .foregroundColor(.red)

                    Text(error)
                        .font(OpenClawType.body)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                Button("Retry", action: self.viewModel.retry)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .padding(.horizontal, 24)
        }
    }

    @ViewBuilder
    private var successSection: some View {
        if self.viewModel.didCompleteSuccessfully {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 48))
                    .foregroundColor(.green)

                Text("Signed in successfully!")
                    .font(OpenClawType.title2)
                    .fontWeight(.semibold)

                Text("You can now use the gateway")
                    .font(OpenClawType.body)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - ViewModel

extension MobileBrokerSignInSheet {
    @MainActor
    public final class ViewModel: ObservableObject {
        // MARK: - Types

        public enum State {
            case idle
            case initiating
            case polling
            case completed(MobileBrokerSessionStore.Session)
            case error(Error)
        }

        // MARK: - Published Properties

        @Published public private(set) var userCode: String?
        @Published public private(set) var verificationURI: URL?
        @Published public private(set) var expiresAt: Date?
        @Published public private(set) var isPolling: Bool = false
        @Published public private(set) var statusMessage: String = ""
        @Published public private(set) var error: String?
        @Published public private(set) var didCompleteSuccessfully: Bool = false

        // MARK: - Computed Properties

        public var timeRemaining: String {
            guard let expiresAt else { return "--:--" }

            let remaining = expiresAt.timeIntervalSinceNow
            if remaining <= 0 {
                return "Expired"
            }

            let minutes = Int(remaining / 60)
            let seconds = Int(remaining.truncatingRemainder(dividingBy: 60))

            return String(format: "%02d:%02d", minutes, seconds)
        }

        public var timeRemainingColor: Color {
            guard let expiresAt else { return .secondary }

            let remaining = expiresAt.timeIntervalSinceNow
            if remaining <= 60 {
                return .red
            } else if remaining <= 120 {
                return .orange
            }
            return .primary
        }

        public var statusMessageColor: Color {
            if self.statusMessage.contains("slow") || self.statusMessage.contains("wait") {
                return .yellow
            } else if self.statusMessage.contains("denied") || self.statusMessage.contains("error") {
                return .red
            } else if self.statusMessage.contains("approved") || self.statusMessage.contains("success") {
                return .green
            }
            return .primary
        }

        // MARK: - Private Properties

        private let authClient: MobileBrokerAuthClient
        private let sessionStore: MobileBrokerSessionStore
        private let gatewayStableID: String
        private let onComplete: (MobileBrokerSessionStore.Session) -> Void
        private let onDismiss: () -> Void
        private var pollingTask: Task<Void, Never>?
        private var currentTransactionID: String?

        // MARK: - Initialization

        public init(
            authClient: MobileBrokerAuthClient,
            sessionStore: MobileBrokerSessionStore,
            gatewayStableID: String,
            onComplete: @escaping (MobileBrokerSessionStore.Session) -> Void,
            onDismiss: @escaping () -> Void)
        {
            self.authClient = authClient
            self.sessionStore = sessionStore
            self.gatewayStableID = gatewayStableID
            self.onComplete = onComplete
            self.onDismiss = onDismiss
        }

        // MARK: - Public Methods

        public func startDeviceFlow() {
            Task {
                await self.initiateDeviceFlow()
            }
        }

        public func stopPolling() {
            self.pollingTask?.cancel()
            self.pollingTask = nil
        }

        public func copyUserCode() {
            guard let userCode else { return }

            UIPasteboard.general.string = userCode

            // Show feedback
            self.statusMessage = "Code copied to clipboard"

            // Clear after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.statusMessage = ""
            }
        }

        public func retry() {
            self.error = nil
            self.didCompleteSuccessfully = false
            self.startDeviceFlow()
        }

        // MARK: - Private Methods

        private func initiateDeviceFlow() async {
            self.isPolling = true
            self.statusMessage = "Initiating sign-in..."

            do {
                let response = try await authClient.initiateDeviceAuthorization()

                // Store transaction ID
                self.currentTransactionID = response.transactionID

                // Update UI
                await MainActor.run {
                    self.userCode = response.userCode
                    self.verificationURI = URL(string: response.verificationURI)
                    self.expiresAt = response.expiresAt
                    self.isPolling = true
                    self.statusMessage = "Waiting for authorization..."
                }

                // Start polling
                self.startPolling()

            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isPolling = false
                }
            }
        }

        private func startPolling() {
            self.pollingTask?.cancel()

            self.pollingTask = Task { @MainActor in
                while !Task.isCancelled {
                    do {
                        guard let transactionID = currentTransactionID else {
                            break
                        }

                        let response = try await authClient.pollDeviceAuthorization(
                            transactionID: transactionID)

                        switch response.status {
                        case .approved:
                            // Success!
                            guard let accessToken = response.accessToken,
                                  let refreshToken = response.refreshToken,
                                  let accessExpiresAt = response.accessExpiresAt,
                                  let refreshExpiresAt = response.refreshExpiresAt,
                                  let subjectEmail = response.subjectEmail
                            else {
                                throw URLError(.cannotParseResponse)
                            }

                            let session = MobileBrokerSessionStore.Session(
                                accessToken: accessToken,
                                refreshToken: refreshToken,
                                accessExpiresAt: accessExpiresAt,
                                refreshExpiresAt: refreshExpiresAt,
                                brokerDeviceID: subjectEmail,
                                brokerHostname: self.authClient.config.hostname)

                            // Store session
                            try self.sessionStore.storeSession(session, forGatewayStableID: self.gatewayStableID)

                            // Notify completion
                            self.didCompleteSuccessfully = true
                            self.isPolling = false
                            self.statusMessage = "Signed in successfully!"

                            // Call completion handler
                            self.onComplete(session)

                            // Dismiss after a delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                self.onDismiss()
                            }

                            return

                        case .slowDown:
                            self.statusMessage = "Please wait..."
                            try await Task.sleep(nanoseconds: UInt64(5 * 1_000_000_000))

                        case .denied:
                            self.error = response.errorMessage ?? "Authorization was denied"
                            self.isPolling = false
                            return

                        case .forbidden:
                            self.error = response.errorMessage ?? "Email not authorized for this Gateway"
                            self.isPolling = false
                            return

                        case .expired:
                            self.error = "Authorization code expired"
                            self.isPolling = false
                            return

                        case .pending:
                            // Continue polling
                            try await Task.sleep(nanoseconds: UInt64(5 * 1_000_000_000))
                        }

                    } catch {
                        // Check if task was cancelled
                        if Task.isCancelled {
                            return
                        }

                        // Check if it's a specific error
                        if let brokerError = error as? MobileBrokerAuthClient.BrokerErrorResponse {
                            self.error = brokerError.errorMessage ?? brokerError.error
                        } else {
                            self.error = error.localizedDescription
                        }
                        self.isPolling = false
                        return
                    }
                }
            }
        }

        // MARK: - Deinitialization

        deinit {
            pollingTask?.cancel()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct MobileBrokerSignInSheet_Previews: PreviewProvider {
    static var previews: some View {
        MobileBrokerSignInSheet(
            viewModel: MobileBrokerSignInSheet.ViewModel(
                authClient: MobileBrokerAuthClient(
                    config: MobileBrokerConfig(hostname: "mobile.claw.example.org")),
                sessionStore: MobileBrokerSessionStore(),
                gatewayStableID: "test-gateway",
                onComplete: { _ in },
                onDismiss: {}))
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
#endif
