//
//  MobileBrokerWatchSupport.swift
//
//  Created for OpenClaw mobile authentication
//

import Foundation
import WatchConnectivity

/// Manages mobile broker authentication support for Apple Watch
/// The Watch does NOT store mobile broker tokens - it relays through the iPhone
public final class MobileBrokerWatchSupport: NSObject, WCSessionDelegate {
    // MARK: - Types

    /// Message types for Watch Connectivity
    public enum MessageType: String {
        case mobileBrokerAuthRequest
        case mobileBrokerAuthResponse
        case mobileBrokerTokenRequest
        case mobileBrokerTokenResponse
        case mobileBrokerRefreshRequest
    }

    /// Response types
    public struct TokenResponse: Codable {
        public let accessToken: String?
        public let needsRefresh: Bool
        public let error: String?
    }

    // MARK: - Properties

    private let sessionStore: MobileBrokerSessionStore
    private let authClient: MobileBrokerAuthClient?
    private var pendingRequests: [String: (Result<TokenResponse, Error>) -> Void] = [:]

    // MARK: - Initialization

    /// Initialize with session store
    /// - Parameter sessionStore: The mobile broker session store
    public init(sessionStore: MobileBrokerSessionStore = KeychainAccessGroupConfig.createSessionStore()) {
        self.sessionStore = sessionStore
        self.authClient = nil // Watch doesn't have direct auth client
        super.init()

        // Configure Watch Connectivity
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: - Token Access

    /// Requests an access token for a gateway from the iPhone
    /// - Parameters:
    ///   - gatewayStableID: The stable identifier of the gateway
    ///   - completion: Completion handler with the token response
    public func requestAccessToken(
        forGatewayStableID gatewayStableID: String,
        completion: @escaping (Result<TokenResponse, Error>) -> Void)
    {
        guard WCSession.default.isReachable else {
            completion(.failure(WatchConnectivityError.notReachable))
            return
        }

        let requestID = UUID().uuidString
        self.pendingRequests[requestID] = completion

        let message: [String: Any] = [
            "type": MessageType.mobileBrokerTokenRequest.rawValue,
            "requestID": requestID,
            "gatewayStableID": gatewayStableID,
        ]

        WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: { error in
            completion(.failure(error))
        })
    }

    /// Requests a refresh for a gateway token from the iPhone
    /// - Parameters:
    ///   - gatewayStableID: The stable identifier of the gateway
    ///   - completion: Completion handler with the token response
    public func requestTokenRefresh(
        forGatewayStableID gatewayStableID: String,
        completion: @escaping (Result<TokenResponse, Error>) -> Void)
    {
        guard WCSession.default.isReachable else {
            completion(.failure(WatchConnectivityError.notReachable))
            return
        }

        let requestID = UUID().uuidString
        self.pendingRequests[requestID] = completion

        let message: [String: Any] = [
            "type": MessageType.mobileBrokerRefreshRequest.rawValue,
            "requestID": requestID,
            "gatewayStableID": gatewayStableID,
        ]

        WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: { error in
            completion(.failure(error))
        })
    }

    // MARK: - WCSessionDelegate

    public func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void)
    {
        guard let type = message["type"] as? String else {
            replyHandler(["error": "Missing type"])
            return
        }

        switch type {
        case MessageType.mobileBrokerTokenRequest.rawValue:
            self.handleTokenRequest(message: message, replyHandler: replyHandler)

        case MessageType.mobileBrokerRefreshRequest.rawValue:
            self.handleRefreshRequest(message: message, replyHandler: replyHandler)

        default:
            replyHandler(["error": "Unknown message type"])
        }
    }

    public func session(
        _ session: WCSession,
        didReceiveMessageData messageData: Data,
        replyHandler: @escaping (Data) -> Void)
    {
        // Handle binary messages if needed
        replyHandler(Data())
    }

    public func sessionReachabilityDidChange(_ session: WCSession) {
        // Reachability changed
    }

    // MARK: - Private Methods

    private func handleTokenRequest(message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let gatewayStableID = message["gatewayStableID"] as? String else {
            replyHandler(["error": "Missing gatewayStableID"])
            return
        }

        let response = if let session = try? sessionStore.retrieveSession(forGatewayStableID: gatewayStableID) {
            if self.sessionStore.isAccessTokenExpired(forGatewayStableID: gatewayStableID) {
                TokenResponse(
                    accessToken: nil,
                    needsRefresh: true,
                    error: nil)
            } else {
                TokenResponse(
                    accessToken: session.accessToken,
                    needsRefresh: false,
                    error: nil)
            }
        } else {
            TokenResponse(
                accessToken: nil,
                needsRefresh: false,
                error: "No session found")
        }

        let reply: [String: Any] = [
            "accessToken": response.accessToken ?? NSNull(),
            "needsRefresh": response.needsRefresh,
            "error": response.error ?? NSNull(),
        ]

        replyHandler(reply)
    }

    private func handleRefreshRequest(message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let gatewayStableID = message["gatewayStableID"] as? String else {
            replyHandler(["error": "Missing gatewayStableID"])
            return
        }

        // For now, just return the current token status
        // In a full implementation, this would trigger a refresh on the iPhone
        self.handleTokenRequest(message: message, replyHandler: replyHandler)
    }

    public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?)
    {
        // Activation completed
    }
}

// MARK: - WatchConnectivityError

public enum WatchConnectivityError: Error, LocalizedError {
    case notReachable
    case sessionNotActive
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .notReachable:
            "iPhone is not reachable"
        case .sessionNotActive:
            "Watch session is not active"
        case .invalidResponse:
            "Invalid response from iPhone"
        }
    }
}
