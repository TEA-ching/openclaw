//
//  GatewayConnectionAuthProvider.swift
//
//  Created for OpenClaw mobile authentication
//

import Foundation

/// Provides authentication headers for gateway connections
protocol GatewayConnectionAuthProvider: Sendable {
    /// Returns the authentication headers for a connection
    /// - Parameter config: The gateway connection configuration
    /// - Returns: Dictionary of headers to add to the request
    func authenticationHeaders(for config: GatewayConnectConfig) -> [String: String]
}

/// Default implementation that handles both standard and mobile broker authentication
final class DefaultGatewayConnectionAuthProvider: GatewayConnectionAuthProvider, Sendable {
    private let mobileBrokerSessionStore: MobileBrokerSessionStore
    private let tokenProvider: GatewayTokenProvider

    init(
        mobileBrokerSessionStore: MobileBrokerSessionStore,
        tokenProvider: GatewayTokenProvider)
    {
        self.mobileBrokerSessionStore = mobileBrokerSessionStore
        self.tokenProvider = tokenProvider
    }

    func authenticationHeaders(for config: GatewayConnectConfig) -> [String: String] {
        if config.usesMobileBroker {
            self.mobileBrokerHeaders(for: config)
        } else {
            self.standardHeaders(for: config)
        }
    }

    private func mobileBrokerHeaders(for config: GatewayConnectConfig) -> [String: String] {
        // An expired token is still returned as-is: the connection attempt fails,
        // and GatewayConnectionController.MobileBrokerAuthState handles refresh/reconnect.
        self.mobileBrokerSessionStore.authorizationHeaders(forURL: config.url, gatewayStableID: config.stableID)
    }

    private func standardHeaders(for config: GatewayConnectConfig) -> [String: String] {
        var headers: [String: String] = [:]

        if let token = tokenProvider.token(for: config) {
            headers["Authorization"] = "Bearer \(token)"
        } else if let bootstrap = config.bootstrapToken {
            headers["X-OpenClaw-Bootstrap"] = bootstrap
        } else if let password = config.password {
            headers["X-OpenClaw-Password"] = password
        }

        return headers
    }
}

/// Protocol for providing gateway tokens
protocol GatewayTokenProvider: Sendable {
    func token(for config: GatewayConnectConfig) -> String?
}

/// Simple token provider that returns a static token
final class StaticTokenProvider: GatewayTokenProvider, Sendable {
    private let token: String

    init(token: String) {
        self.token = token
    }

    func token(for config: GatewayConnectConfig) -> String? {
        self.token
    }
}

/// Token provider that retrieves from GatewaySettingsStore
final class GatewaySettingsTokenProvider: GatewayTokenProvider, Sendable {
    init() {}

    func token(for config: GatewayConnectConfig) -> String? {
        // Retrieve the token for this gateway from settings
        // This is a simplified implementation
        GatewaySettingsStore.mobileBrokerToken(for: config.stableID)
    }
}

// MARK: - GatewaySettingsStore Extension

extension GatewaySettingsStore {
    /// Retrieves the token for a gateway by its stable ID.
    /// GatewaySettingsStore is a static namespace (no instances), so this is a
    /// static member rather than an instance method.
    /// - Parameter stableID: The stable identifier of the gateway
    /// - Returns: The token, or nil if not found
    static func mobileBrokerToken(for stableID: String) -> String? {
        // This is a placeholder - actual implementation would query the stored credentials
        // For now, return nil as the real implementation depends on the existing store structure
        nil
    }

    /// Extra headers for the real Gateway WebSocket upgrade request: the
    /// operator-configured custom headers merged with the mobile-broker
    /// Authorization header (when this route uses the broker). This is the
    /// canonical `extraHeadersProvider` body for every real connect call site
    /// (GatewayNodeSession.connect via NodeAppModel and GatewayOperatorFleet).
    static func loadConnectionHeaders(url: URL, gatewayStableID: String) -> [String: String] {
        self.loadGatewayCustomHeaders(gatewayStableID: gatewayStableID)
            .merging(
                KeychainAccessGroupConfig.createSessionStore()
                    .authorizationHeaders(forURL: url, gatewayStableID: gatewayStableID)) { _, new in new }
    }
}
