//
//  NodeAppModel+MobileBroker.swift
//
//  Created for OpenClaw mobile authentication
//

import Foundation
import OpenClawKit

// MARK: - NodeAppModel Mobile Broker Support

public extension NodeAppModel {
    
    /// Creates a WebSocket session with mobile broker authentication
    /// - Parameters:
    ///   - config: The gateway connection configuration
    ///   - sessionStore: The mobile broker session store
    ///   - role: The role for this connection
    /// - Returns: The WebSocket session
    static func createMobileBrokerWebSocketSession(
        config: GatewayConnectConfig,
        sessionStore: MobileBrokerSessionStore,
        role: GatewayConnectOptions.Role
    ) -> WebSocketSessioning {
        
        // Get the mobile broker config
        guard let brokerConfig = config.mobileBrokerConfig else {
            // Fall back to standard connection
            return WebSocketSession(
                url: config.url,
                protocols: nil,
                headers: [:],
                delegate: NodeWebSocketDelegate()
            )
        }
        
        // Create the WebSocket URL
        var components = URLComponents(url: brokerConfig.webSocketURL, resolvingAgainstBaseURL: false)
        components?.path = config.url.path
        
        guard let wsURL = components?.url else {
            return WebSocketSession(
                url: config.url,
                protocols: nil,
                headers: [:],
                delegate: NodeWebSocketDelegate()
            )
        }
        
        // Get the access token
        let accessToken = try? sessionStore.retrieveSession(forGatewayStableID: config.stableID)?.accessToken
        
        // Create headers
        var headers: [String: String] = [:]
        if let accessToken = accessToken {
            headers["Authorization"] = "Bearer \{accessToken}"
        }
        
        // Add role header
        headers["X-OpenClaw-Role"] = role.rawValue
        
        // Create the session
        return WebSocketSession(
            url: wsURL,
            protocols: nil,
            headers: headers,
            delegate: NodeWebSocketDelegate()
        )
    }
    
    /// Connects to a mobile broker gateway
    /// - Parameters:
    ///   - config: The gateway connection configuration
    ///   - sessionStore: The mobile broker session store
    ///   - role: The role for this connection
    func connectToMobileBrokerGateway(
        config: GatewayConnectConfig,
        sessionStore: MobileBrokerSessionStore,
        role: GatewayConnectOptions.Role
    ) {
        // Create the WebSocket session
        let session = NodeAppModel.createMobileBrokerWebSocketSession(
            config: config,
            sessionStore: sessionStore,
            role: role
        )
        
        // Connect
        connect(with: session)
    }
}

// MARK: - NodeWebSocketDelegate

/// Default WebSocket delegate for NodeAppModel
public class NodeWebSocketDelegate: WebSocketSessionDelegate {
    
    public func webSocketDidOpen(_ session: WebSocketSessioning) {
        // Connection opened
    }
    
    public func webSocket(_ session: WebSocketSessioning, didReceiveMessage message: WebSocketMessage) {
        // Message received
    }
    
    public func webSocket(_ session: WebSocketSessioning, didCloseWithCode code: WebSocketCloseCode) {
        // Connection closed
    }
    
    public func webSocket(_ session: WebSocketSessioning, didFailWithError error: Error) {
        // Connection failed
    }
}

// MARK: - GatewayConnectConfig Mobile Broker WebSocket

public extension GatewayConnectConfig {
    
    /// Creates a WebSocket URL for mobile broker connections
    /// - Returns: The WebSocket URL, or the original URL if not a mobile broker route
    func mobileBrokerWebSocketURL() -> URL {
        if let brokerConfig = mobileBrokerConfig {
            var components = URLComponents(url: brokerConfig.webSocketURL, resolvingAgainstBaseURL: false)
            components?.path = url.path
            components?.query = url.query
            
            if let wsURL = components?.url {
                return wsURL
            }
        }
        
        return url
    }
    
    /// Creates WebSocket headers for mobile broker connections
    /// - Parameter sessionStore: The mobile broker session store
    /// - Returns: Dictionary of headers
    func mobileBrokerWebSocketHeaders(
        sessionStore: MobileBrokerSessionStore
    ) -> [String: String] {
        var headers: [String: String] = [:]
        
        if let session = try? sessionStore.retrieveSession(forGatewayStableID: stableID) {
            headers["Authorization"] = "Bearer \{session.accessToken}"
        }
        
        return headers
    }
}
