//
//  MobileBrokerSessionAccess.swift
//
//  Created for OpenClaw mobile authentication
//

import Foundation

/// Provides access to mobile broker sessions from the Share Extension
/// This uses the same Keychain access group as the main app
public final class MobileBrokerSessionAccess {
    
    // MARK: - Properties
    
    private let sessionStore: MobileBrokerSessionStore
    
    // MARK: - Initialization
    
    /// Initialize with the configured access group
    public init() {
        // Use the same access group as the main app
        self.sessionStore = KeychainAccessGroupConfig.createSessionStore()
    }
    
    // MARK: - Session Access
    
    /// Retrieves a mobile broker session for a gateway
    /// - Parameter gatewayStableID: The stable identifier of the gateway
    /// - Returns: The stored session, or nil if not found
    public func getSession(forGatewayStableID gatewayStableID: String) -> MobileBrokerSessionStore.Session? {
        return try? sessionStore.retrieveSession(forGatewayStableID: gatewayStableID)
    }
    
    /// Checks if the access token for a gateway is expired
    /// - Parameter gatewayStableID: The stable identifier of the gateway
    /// - Returns: true if expired or about to expire
    public func isAccessTokenExpired(forGatewayStableID gatewayStableID: String) -> Bool {
        return sessionStore.isAccessTokenExpired(forGatewayStableID: gatewayStableID)
    }
    
    /// Gets the access token for a gateway
    /// - Parameter gatewayStableID: The stable identifier of the gateway
    /// - Returns: The access token, or nil if not found or expired
    public func getAccessToken(forGatewayStableID gatewayStableID: String) -> String? {
        guard let session = getSession(forGatewayStableID: gatewayStableID) else {
            return nil
        }
        
        if isAccessTokenExpired(forGatewayStableID: gatewayStableID) {
            return nil
        }
        
        return session.accessToken
    }
    
    // MARK: - Refresh Indication
    
    /// Indicates whether a refresh is needed for a gateway
    /// - Parameter gatewayStableID: The stable identifier of the gateway
    /// - Returns: true if the session exists but the token is expired
    public func needsRefresh(forGatewayStableID gatewayStableID: String) -> Bool {
        guard let session = getSession(forGatewayStableID: gatewayStableID) else {
            return false
        }
        
        return sessionStore.isAccessTokenExpired(forGatewayStableID: gatewayStableID)
    }
}
