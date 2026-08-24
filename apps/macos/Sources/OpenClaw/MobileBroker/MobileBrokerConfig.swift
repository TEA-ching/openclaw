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
        components.scheme = self.useTLS ? "https" : "http"
        components.host = self.hostname
        if !self.useTLS, self.port != 80 {
            components.port = self.port
        }
        return components.url!
    }

    /// The WebSocket URL for the broker
    public var webSocketURL: URL {
        var components = URLComponents()
        components.scheme = self.useTLS ? "wss" : "ws"
        components.host = self.hostname
        if !self.useTLS, self.port != 80 {
            components.port = self.port
        }
        return components.url!
    }

    public init(hostname: String, port: Int = 443, useTLS: Bool = true) {
        self.hostname = hostname
        self.port = port
        self.useTLS = useTLS
    }
}

// MARK: - URL Mobile Broker Detection

extension URL {
    /// Whether this URL's host matches common mobile broker naming patterns
    /// (e.g. "mobile.claw.example.org"). Heuristic only: there is no explicit
    /// pairing-time signal yet for "this route uses the broker."
    public var isMobileBrokerHost: Bool {
        guard let host else { return false }
        let lowerHost = host.lowercased()
        return lowerHost.hasPrefix("mobile.") ||
            lowerHost.hasPrefix("mobile-") ||
            lowerHost.contains("-mobile") ||
            lowerHost.contains(".mobile.") ||
            lowerHost.contains(".mobile-")
    }

    /// Mobile broker configuration derived from this URL, if the host matches
    /// the mobile broker naming heuristic.
    public var mobileBrokerConfigFromHost: MobileBrokerConfig? {
        guard self.isMobileBrokerHost, let host else { return nil }
        let useTLS = scheme == "https" || scheme == "wss"
        let effectivePort = port ?? (useTLS ? 443 : 80)
        return MobileBrokerConfig(hostname: host, port: effectivePort, useTLS: useTLS)
    }

    /// The canonical MobileBrokerSessionStore key for this URL, if it's a
    /// mobile-broker host: just the broker hostname. One broker hostname is
    /// one pairing regardless of which UI surface (primary Connection tab,
    /// secondary Gateways-tab profile, Dashboard/Canvas document load) is
    /// asking, so every call site derives the same key from the URL alone --
    /// no profile id or connection-endpoint context needs to be threaded
    /// through to find a session stored elsewhere.
    public var mobileBrokerGatewayStableID: String? {
        self.mobileBrokerConfigFromHost?.hostname
    }
}
