//
//  GatewayConnectionController+MobileBroker.swift
//
//  Created for OpenClaw mobile authentication
//

import Foundation
import Network
import Observation

// MARK: - Mobile Broker Connection Support

public extension GatewayConnectionController {
    
    // MARK: - Mobile Broker State
    
    /// Manages mobile broker authentication state for a gateway
    @MainActor
    @Observable
    final class MobileBrokerAuthState: Sendable {
        
        // MARK: - State
        
        public enum AuthState: Equatable, Sendable {
            case idle
            case authenticating
            case authenticated(MobileBrokerSessionStore.Session)
            case error(Error)
            case needsReauthentication
        }
        
        // MARK: - Properties
        
        private(set) var state: AuthState = .idle
        private(set) var isRefreshing = false
        
        private let gatewayStableID: String
        private let authClient: MobileBrokerAuthClient
        private let sessionStore: MobileBrokerSessionStore
        private let config: GatewayConnectConfig
        
        // MARK: - Initialization
        
        public init(
            gatewayStableID: String,
            authClient: MobileBrokerAuthClient,
            sessionStore: MobileBrokerSessionStore,
            config: GatewayConnectConfig
        ) {
            self.gatewayStableID = gatewayStableID
            self.authClient = authClient
            self.sessionStore = sessionStore
            self.config = config
            
            // Check if we already have a valid session
            checkExistingSession()
        }
        
        // MARK: - Public Methods
        
        /// Starts the mobile broker authentication flow
        public func startAuthentication() {
            Task {
                await performAuthentication()
            }
        }
        
        /// Attempts to refresh the current session
        /// - Returns: true if refresh was successful
        public func refreshSession() async -> Bool {
            guard case let .authenticated(session) = state else {
                return false
            }
            
            isRefreshing = true
            defer { isRefreshing = false }
            
            do {
                let refreshResponse = try await authClient.refreshSession(
                    refreshToken: session.refreshToken
                )
                
                let newSession = MobileBrokerSessionStore.Session(
                    accessToken: refreshResponse.accessToken,
                    refreshToken: refreshResponse.refreshToken,
                    accessExpiresAt: refreshResponse.accessExpiresAt,
                    refreshExpiresAt: refreshResponse.refreshExpiresAt,
                    brokerDeviceID: session.brokerDeviceID,
                    brokerHostname: session.brokerHostname
                )
                
                try sessionStore.refreshSession(newSession, forGatewayStableID: gatewayStableID)
                
                await MainActor.run {
                    state = .authenticated(newSession)
                }
                
                return true
                
            } catch {
                await MainActor.run {
                    state = .needsReauthentication
                }
                return false
            }
        }
        
        /// Revokes the current session
        public func revokeSession() {
            Task {
                await performRevoke()
            }
        }
        
        /// Gets the current access token, refreshing if necessary
        /// - Returns: The access token, or nil if not available
        public func getAccessToken() async -> String? {
            switch state {
            case .idle, .authenticating, .error, .needsReauthentication:
                return nil
            case let .authenticated(session):
                // Check if token is expired or about to expire
                if sessionStore.isAccessTokenExpired(forGatewayStableID: gatewayStableID) {
                    // Try to refresh
                    if await refreshSession() {
                        // Refresh succeeded, get the new token
                        if case let .authenticated(newSession) = state {
                            return newSession.accessToken
                        }
                    }
                    return nil
                }
                return session.accessToken
            }
        }
        
        // MARK: - Private Methods
        
        private func checkExistingSession() {
            Task {
                if let session = try? sessionStore.retrieveSession(forGatewayStableID: gatewayStableID) {
                    // Check if session is still valid
                    if !sessionStore.isAccessTokenExpired(forGatewayStableID: gatewayStableID) {
                        await MainActor.run {
                            state = .authenticated(session)
                        }
                        return
                    }
                }
                
                await MainActor.run {
                    state = .needsReauthentication
                }
            }
        }
        
        @MainActor
        private func performAuthentication() async {
            state = .authenticating
            
            do {
                let session = try await authClient.performDeviceFlow()
                
                try sessionStore.storeSession(session, forGatewayStableID: gatewayStableID)
                
                state = .authenticated(session)
                
            } catch {
                state = .error(error)
            }
        }
        
        @MainActor
        private func performRevoke() async {
            guard case let .authenticated(session) = state else {
                return
            }
            
            do {
                try await authClient.revokeCurrentSession(accessToken: session.accessToken)
            } catch {
                // Ignore revocation errors - we'll still clear local state
            }
            
            do {
                try sessionStore.deleteSession(forGatewayStableID: gatewayStableID)
            } catch {
                // Ignore deletion errors
            }
            
            state = .needsReauthentication
        }
    }
    
    // MARK: - Mobile Broker Auth States
    
    private var mobileBrokerAuthStates: [String: MobileBrokerAuthState] = [:]
    
    // MARK: - Mobile Broker Authentication
    
    /// Gets or creates the mobile broker auth state for a gateway
    /// - Parameter config: The gateway connection configuration
    /// - Returns: The mobile broker auth state
    public func mobileBrokerAuthState(for config: GatewayConnectConfig) -> MobileBrokerAuthState {
        if let existing = mobileBrokerAuthStates[config.stableID] {
            return existing
        }
        
        guard let brokerConfig = config.mobileBrokerConfig else {
            // This shouldn't happen for mobile broker routes
            let state = MobileBrokerAuthState(
                gatewayStableID: config.stableID,
                authClient: MobileBrokerAuthClient(config: MobileBrokerConfig(hostname: "")),
                sessionStore: MobileBrokerSessionStore(),
                config: config
            )
            mobileBrokerAuthStates[config.stableID] = state
            return state
        }
        
        let authClient = MobileBrokerAuthClient(config: brokerConfig)
        let sessionStore = KeychainAccessGroupConfig.createSessionStore()
        
        let state = MobileBrokerAuthState(
            gatewayStableID: config.stableID,
            authClient: authClient,
            sessionStore: sessionStore,
            config: config
        )
        
        mobileBrokerAuthStates[config.stableID] = state
        return state
    }
    
    /// Starts mobile broker authentication for a gateway
    /// - Parameter config: The gateway connection configuration
    public func startMobileBrokerAuthentication(for config: GatewayConnectConfig) {
        guard config.usesMobileBroker else { return }
        
        let state = mobileBrokerAuthState(for: config)
        state.startAuthentication()
    }
    
    /// Gets the access token for a mobile broker gateway
    /// - Parameter config: The gateway connection configuration
    /// - Returns: The access token, or nil if not available
    public func mobileBrokerAccessToken(for config: GatewayConnectConfig) async -> String? {
        guard config.usesMobileBroker else { return nil }
        
        let state = mobileBrokerAuthState(for: config)
        return await state.getAccessToken()
    }
    
    /// Revokes the mobile broker session for a gateway
    /// - Parameter config: The gateway connection configuration
    public func revokeMobileBrokerSession(for config: GatewayConnectConfig) {
        guard config.usesMobileBroker else { return }
        
        let state = mobileBrokerAuthState(for: config)
        state.revokeSession()
    }
    
    /// Clears all mobile broker sessions
    public func clearAllMobileBrokerSessions() {
        mobileBrokerAuthStates.removeAll()
    }
}

// MARK: - GatewayConnectConfig Mobile Broker Helper

public extension GatewayConnectConfig {
    /// Creates a mobile broker authentication header provider
    /// - Returns: A header provider that adds Authorization header for mobile broker routes
    func createMobileBrokerHeaderProvider() -> GatewayConnectionAuthProvider {
        let sessionStore = KeychainAccessGroupConfig.createSessionStore()
        let tokenProvider = StaticTokenProvider(token: "") // Placeholder
        
        return DefaultGatewayConnectionAuthProvider(
            mobileBrokerSessionStore: sessionStore,
            tokenProvider: tokenProvider
        )
    }
}
