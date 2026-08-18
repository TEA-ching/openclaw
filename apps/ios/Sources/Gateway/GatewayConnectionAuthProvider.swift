//
//  GatewayConnectionAuthProvider.swift
//
//  Created for OpenClaw mobile authentication
//

import Foundation

/// Provides authentication headers for gateway connections
public protocol GatewayConnectionAuthProvider: Sendable {
    /// Returns the authentication headers for a connection
    /// - Parameter config: The gateway connection configuration
    /// - Returns: Dictionary of headers to add to the request
    func authenticationHeaders(for config: GatewayConnectConfig) -> [String: String]
}

/// Default implementation that handles both standard and mobile broker authentication
public final class DefaultGatewayConnectionAuthProvider: GatewayConnectionAuthProvider, Sendable {
    
    private let mobileBrokerSessionStore: MobileBrokerSessionStore
    private let tokenProvider: GatewayTokenProvider
    
    public init(
        mobileBrokerSessionStore: MobileBrokerSessionStore,
        tokenProvider: GatewayTokenProvider
    ) {
        self.mobileBrokerSessionStore = mobileBrokerSessionStore
        self.tokenProvider = tokenProvider
    }
    
    public func authenticationHeaders(for config: GatewayConnectConfig) -> [String: String] {
        if config.usesMobileBroker {
            return mobileBrokerHeaders(for: config)
        } else {
            return standardHeaders(for: config)
        }
    }
    
    private func mobileBrokerHeaders(for config: GatewayConnectConfig) -> [String: String] {
        guard let session = try? mobileBrokerSessionStore.retrieveSession(
            forGatewayStableID: config.stableID
        ) else {
            return [:]
        }
        
        // Check if we need to refresh (but don't block - let connection fail and trigger refresh)
        if mobileBrokerSessionStore.isAccessTokenExpired(forGatewayStableID: config.stableID) {
            // Token is expired - return it anyway and let the connection fail
            // The connection controller will handle refresh and reconnect
        }
        
        return [
            "Authorization": "Bearer \{session.accessToken}"
        ]
    }
    
    private func standardHeaders(for config: GatewayConnectConfig) -> [String: String] {
        var headers: [String: String] = [:]
        
        if let token = tokenProvider.token(for: config) {
            headers["Authorization"] = "Bearer \{token}"
        } else if let bootstrap = config.bootstrapToken {
            headers["X-OpenClaw-Bootstrap"] = bootstrap
        } else if let password = config.password {
            headers["X-OpenClaw-Password"] = password
        }
        
        return headers
    }
}

/// Protocol for providing gateway tokens
public protocol GatewayTokenProvider: Sendable {
    func token(for config: GatewayConnectConfig) -> String?
}

/// Simple token provider that returns a static token
public final class StaticTokenProvider: GatewayTokenProvider, Sendable {
    private let token: String
    
    public init(token: String) {
        self.token = token
    }
    
    public func token(for config: GatewayConnectConfig) -> String? {
        return token
    }
}

/// Token provider that retrieves from GatewaySettingsStore
public final class GatewaySettingsTokenProvider: GatewayTokenProvider, Sendable {
    private let settingsStore: GatewaySettingsStore
    
    public init(settingsStore: GatewaySettingsStore) {
        self.settingsStore = settingsStore
    }
    
    public func token(for config: GatewayConnectConfig) -> String? {
        // Retrieve the token for this gateway from settings
        // This is a simplified implementation
        return settingsStore.token(for: config.stableID)
    }
}

// MARK: - GatewaySettingsStore Extension

public extension GatewaySettingsStore {
    /// Retrieves the token for a gateway by its stable ID
    /// - Parameter stableID: The stable identifier of the gateway
    /// - Returns: The token, or nil if not found
    func token(for stableID: String) -> String? {
        // This is a placeholder - actual implementation would query the stored credentials
        // For now, return nil as the real implementation depends on the existing store structure
        return nil
    }
}
