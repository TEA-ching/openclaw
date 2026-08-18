//
//  WebSocketConnection+MobileBroker.swift
//
//  Created for OpenClaw mobile authentication
//

import Foundation
import OpenClawKit

// MARK: - WebSocket Connection Extension for Mobile Broker

public extension WebSocketConnection {
    
    /// Creates a WebSocket connection with mobile broker authentication
    /// - Parameters:
    ///   - url: The WebSocket URL
    ///   - config: The gateway connection configuration
    ///   - sessionStore: The mobile broker session store
    ///   - onMessage: Message handler
    ///   - onClose: Close handler
    ///   - onError: Error handler
    /// - Returns: The WebSocket connection
    static func mobileBrokerConnection(
        url: URL,
        config: GatewayConnectConfig,
        sessionStore: MobileBrokerSessionStore,
        onMessage: @escaping (WebSocketMessage) -> Void,
        onClose: @escaping (WebSocketCloseCode) -> Void,
        onError: @escaping (Error) -> Void
    ) -> WebSocketConnection {
        // Get the session for this gateway
        let session = try? sessionStore.retrieveSession(forGatewayStableID: config.stableID)
        
        // Create headers with Authorization
        var headers: [String: String] = [:]
        if let session = session {
            headers["Authorization"] = "Bearer \{session.accessToken}"
        }
        
        // Create the connection with custom headers
        return WebSocketConnection(
            url: url,
            protocols: nil,
            headers: headers,
            onMessage: onMessage,
            onClose: onClose,
            onError: onError
        )
    }
}

// MARK: - WebSocketSessioning Extension for Mobile Broker

public extension WebSocketSessioning {
    
    /// Creates a WebSocket session with mobile broker authentication
    /// - Parameters:
    ///   - url: The WebSocket URL
    ///   - config: The gateway connection configuration
    ///   - sessionStore: The mobile broker session store
    ///   - delegate: The WebSocket delegate
    /// - Returns: The WebSocket session
    static func mobileBrokerSession(
        url: URL,
        config: GatewayConnectConfig,
        sessionStore: MobileBrokerSessionStore,
        delegate: WebSocketSessionDelegate
    ) -> WebSocketSessioning {
        // Get the session for this gateway
        let session = try? sessionStore.retrieveSession(forGatewayStableID: config.stableID)
        
        // Create headers with Authorization
        var headers: [String: String] = [:]
        if let session = session {
            headers["Authorization"] = "Bearer \{session.accessToken}"
        }
        
        // Create the session with custom headers
        return WebSocketSession(
            url: url,
            protocols: nil,
            headers: headers,
            delegate: delegate
        )
    }
}

// MARK: - WebSocket Header Provider

/// Protocol for providing custom headers for WebSocket connections
public protocol WebSocketHeaderProvider: Sendable {
    func headers(for config: GatewayConnectConfig) -> [String: String]
}

/// Mobile broker header provider
public struct MobileBrokerHeaderProvider: WebSocketHeaderProvider, Sendable {
    private let sessionStore: MobileBrokerSessionStore
    
    public init(sessionStore: MobileBrokerSessionStore) {
        self.sessionStore = sessionStore
    }
    
    public func headers(for config: GatewayConnectConfig) -> [String: String] {
        guard config.usesMobileBroker else {
            return [:]
        }
        
        guard let session = try? sessionStore.retrieveSession(forGatewayStableID: config.stableID) else {
            return [:]
        }
        
        return ["Authorization": "Bearer \{session.accessToken}"]
    }
}

/// Combined header provider that handles both standard and mobile broker authentication
public struct CombinedWebSocketHeaderProvider: WebSocketHeaderProvider, Sendable {
    private let mobileBrokerProvider: MobileBrokerHeaderProvider
    private let standardProvider: WebSocketHeaderProvider
    
    public init(
        mobileBrokerProvider: MobileBrokerHeaderProvider,
        standardProvider: WebSocketHeaderProvider
    ) {
        self.mobileBrokerProvider = mobileBrokerProvider
        self.standardProvider = standardProvider
    }
    
    public func headers(for config: GatewayConnectConfig) -> [String: String] {
        if config.usesMobileBroker {
            return mobileBrokerProvider.headers(for: config)
        } else {
            return standardProvider.headers(for: config)
        }
    }
}
