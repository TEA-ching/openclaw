//
//  GatewayConnectConfig+MobileBroker.swift
//
//  Created for OpenClaw mobile authentication
//

import Foundation

extension GatewayConnectConfig {
    // MARK: - Authentication Mode

    /// The authentication mode for this gateway connection
    public enum AuthenticationMode: Equatable, Hashable, Sendable {
        /// Standard gateway credentials (token, bootstrap, password)
        case gatewayCredentials
        /// Mobile broker authentication with opaque tokens
        case mobileBroker(routeStableID: String, brokerOrigin: MobileBrokerConfig)
    }

    // MARK: - Mobile Broker Host Detection

    /// Whether this connection's URL host matches common mobile broker naming
    /// patterns (e.g. "mobile.claw.example.org"). Heuristic only: there is no
    /// explicit pairing-time signal yet for "this route uses the broker."
    public var isMobileBrokerHost: Bool {
        url.isMobileBrokerHost
    }

    /// Mobile broker configuration derived from this connection's URL, if the
    /// host matches the mobile broker naming heuristic.
    public var mobileBrokerConfigFromURL: MobileBrokerConfig? {
        url.mobileBrokerConfigFromHost
    }

    // MARK: - Properties

    /// The authentication mode for this connection
    public var authenticationMode: AuthenticationMode {
        // Check if this is a mobile broker route
        if let brokerConfig = mobileBrokerConfigFromURL {
            return .mobileBroker(routeStableID: stableID, brokerOrigin: brokerConfig)
        }

        return .gatewayCredentials
    }

    // MARK: - Mobile Broker Support

    /// Whether this connection uses mobile broker authentication
    public var usesMobileBroker: Bool {
        if case .mobileBroker = self.authenticationMode {
            return true
        }
        return false
    }

    /// The mobile broker configuration, if applicable
    public var mobileBrokerConfig: MobileBrokerConfig? {
        if case let .mobileBroker(_, config) = authenticationMode {
            return config
        }
        return self.mobileBrokerConfigFromURL
    }

    // MARK: - Token Access

    /// Returns the access token for mobile broker authentication, if available
    public var mobileBrokerAccessToken: String? {
        guard self.usesMobileBroker else { return nil }
        let store = KeychainAccessGroupConfig.createSessionStore()
        return (try? store.retrieveSession(forGatewayStableID: stableID))?.accessToken
    }
}

// MARK: - GatewayConnectConfig Equality Extension

extension GatewayConnectConfig {
    /// Two configs are equal if they have the same authentication mode and identity
    public func hasSameConnectionInputsMobileBroker(as other: GatewayConnectConfig) -> Bool {
        // Check if both use mobile broker
        if self.usesMobileBroker != other.usesMobileBroker {
            return false
        }

        // If both use mobile broker, check the broker config
        if self.usesMobileBroker, other.usesMobileBroker {
            return self.mobileBrokerConfig == other.mobileBrokerConfig &&
                self.stableID == other.stableID &&
                self.url == other.url
        }

        // Fall back to standard equality
        return hasSameConnectionInputs(as: other)
    }
}
