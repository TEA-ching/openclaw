//
//  WebSocketConnection+MobileBroker.swift
//
//  Created for OpenClaw mobile authentication
//

import Foundation
import OpenClawKit

// MARK: - WebSocket Header Provider

//
// The real Gateway WebSocket connection (GatewayNodeSession -> GatewayChannelActor
// in OpenClawKit) takes headers via an `extraHeadersProvider` closure attached to
// the upgrade URLRequest, not via a bespoke connection/session type. There is no
// WebSocketConnection/WebSocketSession type in this codebase to extend; header
// computation for that real path goes through MobileBrokerSessionStore.authorizationHeaders(forURL:gatewayStableID:).

/// Protocol for providing custom headers for WebSocket connections
protocol WebSocketHeaderProvider: Sendable {
    func headers(for config: GatewayConnectConfig) -> [String: String]
}

/// Mobile broker header provider
struct MobileBrokerHeaderProvider: WebSocketHeaderProvider, Sendable {
    private let sessionStore: MobileBrokerSessionStore

    init(sessionStore: MobileBrokerSessionStore) {
        self.sessionStore = sessionStore
    }

    func headers(for config: GatewayConnectConfig) -> [String: String] {
        self.sessionStore.authorizationHeaders(forURL: config.url, gatewayStableID: config.stableID)
    }
}

/// Combined header provider that handles both standard and mobile broker authentication
struct CombinedWebSocketHeaderProvider: WebSocketHeaderProvider, Sendable {
    private let mobileBrokerProvider: MobileBrokerHeaderProvider
    private let standardProvider: WebSocketHeaderProvider

    init(
        mobileBrokerProvider: MobileBrokerHeaderProvider,
        standardProvider: WebSocketHeaderProvider)
    {
        self.mobileBrokerProvider = mobileBrokerProvider
        self.standardProvider = standardProvider
    }

    func headers(for config: GatewayConnectConfig) -> [String: String] {
        if config.usesMobileBroker {
            self.mobileBrokerProvider.headers(for: config)
        } else {
            self.standardProvider.headers(for: config)
        }
    }
}
