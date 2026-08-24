//
//  MobileBrokerSignInSheet.swift
//
//  Created for OpenClaw mobile authentication
//

import AppKit
import SwiftUI

/// SwiftUI view for mobile broker sign-in using GitHub Device Flow
@MainActor
struct MobileBrokerSignInSheet: View {
    // MARK: - State

    @State private var viewModel: ViewModel

    // MARK: - Initialization

    init(viewModel: ViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    // MARK: - View

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 40))
                    .foregroundStyle(.tint)
                    .accessibilityLabel("Security")

                Text("Sign In with GitHub")
                    .font(.title2.weight(.semibold))

                Text("Complete the sign-in on GitHub")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)
            .padding(.bottom, 16)

            VStack(spacing: 20) {
                self.userCodeSection
                self.expirationSection
                self.verificationURISection
                self.statusSection
                if self.viewModel.isPolling {
                    self.progressIndicator
                }
                self.errorSection
                self.successSection
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            Divider()

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    self.viewModel.cancel()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(16)
        }
        .frame(width: 420)
        .task {
            self.viewModel.startDeviceFlow()
        }
        .onDisappear {
            self.viewModel.stopPolling()
        }
    }

    // MARK: - Subviews

    private var userCodeSection: some View {
        VStack(spacing: 10) {
            Text("Enter this code on GitHub:")
                .font(.headline)

            Text(self.viewModel.userCode ?? "...")
                .font(.title.weight(.bold).monospaced())
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(nsColor: .quaternarySystemFill)))

            Button {
                self.viewModel.copyUserCode()
            } label: {
                Label("Copy Code", systemImage: "doc.on.doc")
            }
            .disabled(self.viewModel.userCode == nil)
        }
    }

    @ViewBuilder
    private var expirationSection: some View {
        if viewModel.expiresAt != nil {
            VStack(spacing: 4) {
                Text("Code expires in:")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(self.viewModel.timeRemaining)
                    .font(.headline)
                    .foregroundStyle(self.viewModel.timeRemainingColor)
            }
        }
    }

    private var verificationURISection: some View {
        VStack(spacing: 8) {
            Text("Then visit:")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let uri = viewModel.verificationURI {
                Link(destination: uri) {
                    Text(uri.absoluteString)
                        .font(.headline)
                        .lineLimit(1)
                }
            } else {
                Text("...")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if !self.viewModel.statusMessage.isEmpty {
            Text(self.viewModel.statusMessage)
                .font(.body)
                .foregroundStyle(self.viewModel.statusMessageColor)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var progressIndicator: some View {
        ProgressView()
            .controlSize(.small)
            .padding(.vertical, 4)
    }

    @ViewBuilder
    private var errorSection: some View {
        if let error = viewModel.error {
            VStack(spacing: 12) {
                VStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 20))
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.body)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
                Button("Retry") {
                    self.viewModel.retry()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    @ViewBuilder
    private var successSection: some View {
        if self.viewModel.didCompleteSuccessfully {
            VStack(spacing: 6) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)
                Text("Signed in successfully!")
                    .font(.title2.weight(.semibold))
                Text("You can now connect to this Gateway")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - ViewModel

extension MobileBrokerSignInSheet {
    @MainActor
    @Observable
    final class ViewModel {
        // MARK: - Published Properties

        private(set) var userCode: String?
        private(set) var verificationURI: URL?
        private(set) var expiresAt: Date?
        private(set) var isPolling = false
        private(set) var statusMessage = ""
        private(set) var error: String?
        private(set) var didCompleteSuccessfully = false

        // MARK: - Computed Properties

        var timeRemaining: String {
            guard let expiresAt else { return "--:--" }
            let remaining = expiresAt.timeIntervalSinceNow
            if remaining <= 0 { return "Expired" }
            let minutes = Int(remaining / 60)
            let seconds = Int(remaining.truncatingRemainder(dividingBy: 60))
            return String(format: "%02d:%02d", minutes, seconds)
        }

        var timeRemainingColor: Color {
            guard let expiresAt else { return .secondary }
            let remaining = expiresAt.timeIntervalSinceNow
            if remaining <= 60 { return .red }
            if remaining <= 120 { return .orange }
            return .primary
        }

        var statusMessageColor: Color {
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
        // @ObservationIgnored (not view-rendered state) also sidesteps
        // @Observable's macro-synthesized storage, which otherwise rejects
        // `nonisolated` on this var -- needed because deinit cancels it from
        // a nonisolated context. By the time deinit runs, no other reference
        // to self remains, so unchecked access here races with nothing.
        @ObservationIgnored
        private nonisolated(unsafe) var pollingTask: Task<Void, Never>?
        @ObservationIgnored
        private var currentTransactionID: String?

        // MARK: - Initialization

        init(
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

        func startDeviceFlow() {
            Task {
                await self.initiateDeviceFlow()
            }
        }

        func stopPolling() {
            self.pollingTask?.cancel()
            self.pollingTask = nil
        }

        func cancel() {
            self.stopPolling()
            self.onDismiss()
        }

        func copyUserCode() {
            guard let userCode else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(userCode, forType: .string)
            self.statusMessage = "Code copied to clipboard"
            Task {
                try? await Task.sleep(for: .seconds(2))
                if self.statusMessage == "Code copied to clipboard" {
                    self.statusMessage = ""
                }
            }
        }

        func retry() {
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
                self.currentTransactionID = response.transactionID
                self.userCode = response.userCode
                self.verificationURI = URL(string: response.verificationURI)
                self.expiresAt = response.expiresAt
                self.isPolling = true
                self.statusMessage = "Waiting for authorization..."
                self.startPolling()
            } catch {
                self.error = error.localizedDescription
                self.isPolling = false
            }
        }

        private func startPolling() {
            self.pollingTask?.cancel()

            self.pollingTask = Task {
                while !Task.isCancelled {
                    do {
                        guard let transactionID = currentTransactionID else { break }

                        let response = try await authClient.pollDeviceAuthorization(
                            transactionID: transactionID)

                        switch response.status {
                        case .approved:
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

                            try self.sessionStore.storeSession(session, forGatewayStableID: self.gatewayStableID)

                            self.didCompleteSuccessfully = true
                            self.isPolling = false
                            self.statusMessage = "Signed in successfully!"
                            self.onComplete(session)

                            try? await Task.sleep(for: .seconds(1.5))
                            self.onDismiss()
                            return

                        case .slowDown:
                            self.statusMessage = "Please wait..."
                            try await Task.sleep(for: .seconds(5))

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
                            try await Task.sleep(for: .seconds(5))
                        }
                    } catch {
                        if Task.isCancelled { return }
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

        deinit {
            pollingTask?.cancel()
        }
    }
}
