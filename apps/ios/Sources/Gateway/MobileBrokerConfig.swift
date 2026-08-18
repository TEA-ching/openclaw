//
//  MobileBrokerConfig.swift
//
//  Created for OpenClaw mobile authentication
//

import Foundation

/// Configuration for the mobile authentication broker
public struct MobileBrokerConfig: Codable, Equatable, Hashable, Sendable {
    /// The hostname of the mobile broker (e.g., "mobile.claw.example.org")
    public let hostname: String
    
    /// The port of the mobile broker (default: 443 for HTTPS)
    public let port: Int
    
    /// Whether to use TLS (default: true)
    public let useTLS: Bool
    
    /// The base URL for the broker API
    public var baseURL: URL {
        var components = URLComponents()
        components.scheme = useTLS ? "https" : "http"
        components.host = hostname
        if !useTLS && port != 80 {
            components.port = port
        }
        return components.url!
    }
    
    /// The WebSocket URL for the broker
    public var webSocketURL: URL {
        var components = URLComponents()
        components.scheme = useTLS ? "wss" : "ws"
        components.host = hostname
        if !useTLS && port != 80 {
            components.port = port
        }
        return components.url!
    }
    
    public init(hostname: String, port: Int = 443, useTLS: Bool = true) {
        self.hostname = hostname
        self.port = port
        self.useTLS = useTLS
    }
}

// MARK: - Gateway Route Extension

public extension GatewayRoute {
    /// Whether this route uses mobile broker authentication
    var isMobileBrokerRoute: Bool {
        // Check if the host matches common mobile broker patterns
        // This is a simple heuristic - actual implementation should check against configured mobile broker hostnames
        let lowerHost = host.lowercased()
        return lowerHost.hasPrefix("mobile.") || 
               lowerHost.contains("-mobile") ||
               lowerHost.contains(".mobile.")
    }
    
    /// Mobile broker configuration for this route, if applicable
    var mobileBrokerConfig: MobileBrokerConfig? {
        guard isMobileBrokerRoute else { return nil }
        return MobileBrokerConfig(hostname: host, port: port, useTLS: isTLS)
    }
}
