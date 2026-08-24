//
//  MobileBrokerSessionStore.swift
//
//  Created for OpenClaw mobile authentication
//

import Foundation
import Security

/// Stores mobile broker session credentials in the Keychain.
///
/// Unlike iOS (which shares this Keychain item across the app and a Share
/// Extension/Watch App via an App Group access group), macOS ships as one
/// unsandboxed app with no extension needing shared Keychain access -- so
/// this store always uses the app's own default Keychain access group.
public final class MobileBrokerSessionStore: Sendable {
    // MARK: - Types

    /// Represents a stored mobile broker session
    public struct Session: Codable, Sendable {
        public let accessToken: String
        public let refreshToken: String
        public let accessExpiresAt: Date
        public let refreshExpiresAt: Date
        public let brokerDeviceID: String
        public let brokerHostname: String

        public init(
            accessToken: String,
            refreshToken: String,
            accessExpiresAt: Date,
            refreshExpiresAt: Date,
            brokerDeviceID: String,
            brokerHostname: String)
        {
            self.accessToken = accessToken
            self.refreshToken = refreshToken
            self.accessExpiresAt = accessExpiresAt
            self.refreshExpiresAt = refreshExpiresAt
            self.brokerDeviceID = brokerDeviceID
            self.brokerHostname = brokerHostname
        }
    }

    // MARK: - Shared Instance

    public static let shared = MobileBrokerSessionStore()

    // MARK: - Initialization

    public init() {}

    // MARK: - Keychain Keys

    private func keychainKey(for gatewayStableID: String) -> String {
        "com.openclaw.mobileBrokerSession.\(gatewayStableID)"
    }

    // MARK: - Store Session

    /// Stores a mobile broker session for a gateway
    /// - Parameters:
    ///   - session: The session to store
    ///   - gatewayStableID: The stable identifier of the gateway
    /// - Throws: Keychain error
    public func storeSession(_ session: Session, forGatewayStableID gatewayStableID: String) throws {
        let data = try JSONEncoder().encode(session)

        // Plain legacy macOS Keychain, matching MacGatewayProfileStore's own
        // query shape: kSecUseDataProtectionKeychain requires a
        // keychain-access-groups entitlement this single, unsandboxed app
        // doesn't have, and fails writes with errSecMissingEntitlement (-34018).
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: self.keychainKey(for: gatewayStableID),
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
    }

    // MARK: - Retrieve Session

    /// Retrieves a mobile broker session for a gateway
    /// - Parameter gatewayStableID: The stable identifier of the gateway
    /// - Returns: The stored session, or nil if not found
    /// - Throws: Keychain error
    public func retrieveSession(forGatewayStableID gatewayStableID: String) throws -> Session? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: self.keychainKey(for: gatewayStableID),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status != errSecItemNotFound else {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }

        guard let data = item as? Data else {
            return nil
        }

        return try JSONDecoder().decode(Session.self, from: data)
    }

    // MARK: - Delete Session

    /// Deletes a mobile broker session for a gateway
    /// - Parameter gatewayStableID: The stable identifier of the gateway
    /// - Throws: Keychain error
    public func deleteSession(forGatewayStableID gatewayStableID: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: self.keychainKey(for: gatewayStableID),
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }

    // MARK: - Check Expiration

    /// Checks if the access token for a gateway is expired or about to expire
    /// - Parameters:
    ///   - gatewayStableID: The stable identifier of the gateway
    ///   - skewWindow: Time interval to consider as "about to expire"
    /// - Returns: true if expired or about to expire
    public func isAccessTokenExpired(
        forGatewayStableID gatewayStableID: String,
        skewWindow: TimeInterval = 30) -> Bool
    {
        guard let session = try? retrieveSession(forGatewayStableID: gatewayStableID) else {
            return true
        }

        let now = Date()
        let expiresSoon = session.accessExpiresAt.addingTimeInterval(-skewWindow)
        return now >= expiresSoon
    }

    // MARK: - Refresh Session

    /// Refreshes the session by storing new tokens
    /// - Parameters:
    ///   - newSession: The new session with updated tokens
    ///   - gatewayStableID: The stable identifier of the gateway
    /// - Throws: Keychain error
    public func refreshSession(_ newSession: Session, forGatewayStableID gatewayStableID: String) throws {
        try self.storeSession(newSession, forGatewayStableID: gatewayStableID)
    }

    // MARK: - WebSocket Authorization Header

    /// The Authorization header to attach to a gateway WebSocket upgrade request,
    /// if this URL is a mobile broker route and a stored session exists.
    public func authorizationHeaders(forURL url: URL, gatewayStableID: String) -> [String: String] {
        guard url.isMobileBrokerHost else { return [:] }
        guard let session = try? retrieveSession(forGatewayStableID: gatewayStableID) else { return [:] }
        return ["Authorization": "Bearer \(session.accessToken)"]
    }

    // MARK: - Proactive Refresh

    /// Refreshes the stored mobile-broker session for this route if its access
    /// token is expired or about to expire, using the persisted refresh token
    /// (30-day TTL) -- so a reconnect after the 1-hour access token lapses
    /// re-authenticates silently instead of sending a stale token the broker
    /// rejects with no user-visible explanation. Call this before every
    /// mobile-broker connect attempt, not just the manual sign-in flow. No-op,
    /// silently, when this isn't a mobile broker route, no session is stored,
    /// the token isn't due for refresh, or the refresh call itself fails (the
    /// subsequent connect attempt then fails with the stale token, surfacing
    /// the real problem instead of masking a refresh error behind a swallowed
    /// success).
    public func refreshIfNeeded(forURL url: URL, gatewayStableID: String) async {
        guard url.isMobileBrokerHost else { return }
        guard let session = try? retrieveSession(forGatewayStableID: gatewayStableID) else { return }
        guard self.isAccessTokenExpired(forGatewayStableID: gatewayStableID) else { return }
        guard let brokerConfig = url.mobileBrokerConfigFromHost else { return }

        let authClient = MobileBrokerAuthClient(config: brokerConfig)
        guard let refreshed = try? await authClient.refreshSession(refreshToken: session.refreshToken) else {
            return
        }

        let newSession = Session(
            accessToken: refreshed.accessToken,
            refreshToken: refreshed.refreshToken,
            accessExpiresAt: refreshed.accessExpiresAt,
            refreshExpiresAt: refreshed.refreshExpiresAt,
            brokerDeviceID: session.brokerDeviceID,
            brokerHostname: session.brokerHostname)
        try? self.refreshSession(newSession, forGatewayStableID: gatewayStableID)
    }
}

// MARK: - KeychainError

public enum KeychainError: Error, LocalizedError {
    case unhandledError(status: OSStatus)

    public var errorDescription: String? {
        switch self {
        case let .unhandledError(status):
            String(format: "Keychain error: %d", status)
        }
    }
}
