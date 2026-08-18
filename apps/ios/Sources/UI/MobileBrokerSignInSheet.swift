//
//  MobileBrokerSignInSheet.swift
//
//  Created for OpenClaw mobile authentication
//

import SwiftUI
import OpenClawType

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
                    .foregroundColor(.accentColor)
                    .accessibilityLabel("Security")
                
                OpenClawType.title2("Sign In with GitHub")
                    .fontWeight(.semibold)
                
                OpenClawType.subheadline("Complete the sign-in on your device")
                    .foregroundColor(.secondary)
            }
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            ScrollView {
                VStack(spacing: 24) {
                    // User Code Display
                    userCodeSection
                    
                    // Expiration countdown
                    expirationSection
                    
                    // Verification URI
                    verificationURISection
                    
                    // Status
                    statusSection
                    
                    // Progress indicator
                    if viewModel.isPolling {
                        progressIndicator
                    }
                    
                    // Error state
                    errorSection
                    
                    // Success state
                    successSection
                    
                    Spacer()
                        .frame(height: 24)
                }
                .padding(.horizontal, 24)
            }
        }
        .onAppear {
            viewModel.startDeviceFlow()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var userCodeSection: some View {
        VStack(spacing: 12) {
            OpenClawType.headline("Enter this code on GitHub:")
            
            // User code in a styled box with branded typography
            OpenClawType.title1(viewModel.userCode ?? "...")
                .fontWeight(.bold)
                .monospacedDigit()
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray3), lineWidth: 1)
                )
            
            // Copy button with branded typography
            Button(action: viewModel.copyUserCode) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.doc")
                    OpenClawType.callout("Copy Code")
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.accentColor)
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(viewModel.userCode == nil)
        }
    }
    
    @ViewBuilder
    private var expirationSection: some View {
        if let expiresAt = viewModel.expiresAt {
            VStack(spacing: 4) {
                OpenClawType.footnote("Code expires in:")
                    .foregroundColor(.secondary)
                
                OpenClawType.headline(viewModel.timeRemaining)
                    .foregroundColor(viewModel.timeRemainingColor)
            }
        }
    }
    
    @ViewBuilder
    private var verificationURISection: some View {
        VStack(spacing: 8) {
            OpenClawType.footnote("Then visit:")
                .foregroundColor(.secondary)
            
            if let uri = viewModel.verificationURI {
                Link(
                    destination: uri,
                    label: {
                        OpenClawType.headline(uri.absoluteString)
                            .foregroundColor(.accentColor)
                            .lineLimit(1)
                    }
                )
            } else {
                OpenClawType.headline("...")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var statusSection: some View {
        if !viewModel.statusMessage.isEmpty {
            OpenClawType.body(viewModel.statusMessage)
                .foregroundColor(viewModel.statusMessageColor)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
    
    @ViewBuilder
    private var progressIndicator: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
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
                    
                    OpenClawType.body(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                
                Button("Retry", action: viewModel.retry)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .padding(.horizontal, 24)
        }
    }
    
    @ViewBuilder
    private var successSection: some View {
        if viewModel.didCompleteSuccessfully {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                
                OpenClawType.title2("Signed in successfully!")
                    .fontWeight(.semibold)
                
                OpenClawType.body("You can now use the gateway")
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - ViewModel

public extension MobileBrokerSignInSheet {
    @MainActor
    final class ViewModel: ObservableObject {
        
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
            guard let expiresAt = expiresAt else { return "--:--" }
            
            let remaining = expiresAt.timeIntervalSinceNow
            if remaining <= 0 {
                return "Expired"
            }
            
            let minutes = Int(remaining / 60)
            let seconds = Int(remaining.truncatingRemainder(dividingBy: 60))
            
            return String(format: "%02d:%02d", minutes, seconds)
        }
        
        public var timeRemainingColor: Color {
            guard let expiresAt = expiresAt else { return .secondary }
            
            let remaining = expiresAt.timeIntervalSinceNow
            if remaining <= 60 {
                return .red
            } else if remaining <= 120 {
                return .orange
            }
            return .primary
        }
        
        public var statusMessageColor: Color {
            if statusMessage.contains("slow") || statusMessage.contains("wait") {
                return .yellow
            } else if statusMessage.contains("denied") || statusMessage.contains("error") {
                return .red
            } else if statusMessage.contains("approved") || statusMessage.contains("success") {
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
            onDismiss: @escaping () -> Void
        ) {
            self.authClient = authClient
            self.sessionStore = sessionStore
            self.gatewayStableID = gatewayStableID
            self.onComplete = onComplete
            self.onDismiss = onDismiss
        }
        
        // MARK: - Public Methods
        
        public func startDeviceFlow() {
            Task {
                await initiateDeviceFlow()
            }
        }
        
        public func stopPolling() {
            pollingTask?.cancel()
            pollingTask = nil
        }
        
        public func copyUserCode() {
            guard let userCode = userCode else { return }
            
            UIPasteboard.general.string = userCode
            
            // Show feedback
            statusMessage = "Code copied to clipboard"
            
            // Clear after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.statusMessage = ""
            }
        }
        
        public func retry() {
            error = nil
            didCompleteSuccessfully = false
            startDeviceFlow()
        }
        
        // MARK: - Private Methods
        
        private func initiateDeviceFlow() async {
            isPolling = true
            statusMessage = "Initiating sign-in..."
            
            do {
                let response = try await authClient.initiateDeviceAuthorization()
                
                // Store transaction ID
                currentTransactionID = response.transactionID
                
                // Update UI
                await MainActor.run {
                    userCode = response.userCode
                    verificationURI = response.verificationURI
                    expiresAt = response.expiresAt
                    isPolling = true
                    statusMessage = "Waiting for authorization..."
                }
                
                // Start polling
                startPolling()
                
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isPolling = false
                }
            }
        }
        
        private func startPolling() {
            pollingTask?.cancel()
            
            pollingTask = Task { @MainActor in
                while !Task.isCancelled {
                    do {
                        guard let transactionID = currentTransactionID else {
                            break
                        }
                        
                        let response = try await authClient.pollDeviceAuthorization(
                            transactionID: transactionID
                        )
                        
                        switch response.status {
                        case .approved:
                            // Success!
                            guard let accessToken = response.accessToken,
                                  let refreshToken = response.refreshToken,
                                  let accessExpiresAt = response.accessExpiresAt,
                                  let refreshExpiresAt = response.refreshExpiresAt,
                                  let subjectEmail = response.subjectEmail else {
                                throw URLError(.cannotParseResponse)
                            }
                            
                            let session = MobileBrokerSessionStore.Session(
                                accessToken: accessToken,
                                refreshToken: refreshToken,
                                accessExpiresAt: accessExpiresAt,
                                refreshExpiresAt: refreshExpiresAt,
                                brokerDeviceID: subjectEmail,
                                brokerHostname: authClient.config.hostname
                            )
                            
                            // Store session
                            try sessionStore.storeSession(session, forGatewayStableID: gatewayStableID)
                            
                            // Notify completion
                            didCompleteSuccessfully = true
                            isPolling = false
                            statusMessage = "Signed in successfully!"
                            
                            // Call completion handler
                            onComplete(session)
                            
                            // Dismiss after a delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                onDismiss()
                            }
                            
                            return
                            
                        case .slowDown:
                            statusMessage = "Please wait..."
                            try await Task.sleep(nanoseconds: UInt64(5 * 1_000_000_000))
                            
                        case .denied:
                            error = response.errorMessage ?? "Authorization was denied"
                            isPolling = false
                            return
                            
                        case .forbidden:
                            error = response.errorMessage ?? "Email not authorized for this Gateway"
                            isPolling = false
                            return
                            
                        case .expired:
                            error = "Authorization code expired"
                            isPolling = false
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
                            error = brokerError.errorMessage ?? brokerError.error
                        } else {
                            error = error.localizedDescription
                        }
                        isPolling = false
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
                    config: MobileBrokerConfig(hostname: "mobile.claw.example.org")
                ),
                sessionStore: MobileBrokerSessionStore(),
                gatewayStableID: "test-gateway",
                onComplete: { _ in },
                onDismiss: {}
            )
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
