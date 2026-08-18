//
//  GatewayConnectConfig+MobileBroker.swift
//
//  Created for OpenClaw mobile authentication
//

import Foundation

public extension GatewayConnectConfig {
    
    // MARK: - Authentication Mode
    
    /// The authentication mode for this gateway connection
    public enum AuthenticationMode: Equatable, Hashable, Sendable {
        /// Standard gateway credentials (token, bootstrap, password)
        case gatewayCredentials
        /// Mobile broker authentication with opaque tokens
        case mobileBroker(routeStableID: String, brokerOrigin: MobileBrokerConfig)
    }
    
    // MARK: - Properties
    
    /// The authentication mode for this connection
    public var authenticationMode: AuthenticationMode {
        // Check if this is a mobile broker route
        if let brokerConfig = route.mobileBrokerConfig {
            return .mobileBroker(routeStableID: stableID, brokerOrigin: brokerConfig)
        }
        
        // Check if we have any of the standard credentials
        if token != nil || bootstrapToken != nil || password != nil {
            return .gatewayCredentials
        }
        
        return .gatewayCredentials
    }
    
    // MARK: - Mobile Broker Support
    
    /// Whether this connection uses mobile broker authentication
    public var usesMobileBroker: Bool {
        if case .mobileBroker = authenticationMode {
            return true
        }
        return false
    }
    
    /// The mobile broker configuration, if applicable
    public var mobileBrokerConfig: MobileBrokerConfig? {
        if case let .mobileBroker(_, config) = authenticationMode {
            return config
        }
        return route.mobileBrokerConfig
    }
    
    // MARK: - Token Access
    
    /// Returns the access token for mobile broker authentication, if available
    public var mobileBrokerAccessToken: String? {
        // This would be retrieved from MobileBrokerSessionStore in practice
        // For now, return nil as it requires the session store
        return nil
    }
}

// MARK: - AuthenticationMode Equality

extension GatewayConnectConfig.AuthenticationMode: Equatable {
    public static func == (lhs: GatewayConnectConfig.AuthenticationMode, rhs: GatewayConnectConfig.AuthenticationMode) -> Bool {
        switch (lhs, rhs) {
        case (.gatewayCredentials, .gatewayCredentials):
            return true
        case let (.mobileBroker(lhsID, lhsConfig), .mobileBroker(rhsID, rhsConfig)):
            return lhsID == rhsID && lhsConfig == rhsConfig
        default:
            return false
        }
    }
}

// MARK: - AuthenticationMode Hashable

extension GatewayConnectConfig.AuthenticationMode: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .gatewayCredentials:
            hasher.combine("gatewayCredentials")
        case let .mobileBroker(routeID, config):
            hasher.combine("mobileBroker")
            hasher.combine(routeID)
            hasher.combine(config)
        }
    }
}

// MARK: - GatewayConnectConfig Equality Extension

public extension GatewayConnectConfig {
    /// Two configs are equal if they have the same authentication mode and identity
    func hasSameConnectionInputsMobileBroker(as other: GatewayConnectConfig) -> Bool {
        // Check if both use mobile broker
        if self.usesMobileBroker != other.usesMobileBroker {
            return false
        }
        
        // If both use mobile broker, check the broker config
        if self.usesMobileBroker && other.usesMobileBroker {
            return self.mobileBrokerConfig == other.mobileBrokerConfig &&
                   self.stableID == other.stableID &&
                   self.route == other.route
        }
        
        // Fall back to standard equality
        return hasSameConnectionInputs(as: other)
    }
}
