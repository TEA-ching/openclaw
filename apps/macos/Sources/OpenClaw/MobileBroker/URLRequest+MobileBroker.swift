//
//  URLRequest+MobileBroker.swift
//
//  Created for OpenClaw mobile authentication
//

import Foundation

extension URLRequest {
    /// Attaches the mobile-broker Bearer token to this request's headers when
    /// its URL is a mobile-broker host and a session is stored for it.
    ///
    /// The WebSocket connect path authenticates via `extraHeadersProvider`
    /// (GatewayConnection.configure / MacNodeModeCoordinator.connect); this is
    /// the equivalent for plain HTTP document loads -- Dashboard and Canvas
    /// windows load their Gateway-hosted page via a bare `URLRequest`, which
    /// otherwise carries no auth at all, and the broker's HandleHTTP rejects
    /// it with "Missing Authorization header" before ever reaching the
    /// Gateway. No-op for non-broker URLs or when no session is stored yet.
    mutating func attachMobileBrokerAuthorizationIfNeeded() {
        guard let url else { return }
        for (field, value) in MobileBrokerSessionStore.shared.authorizationHeaders(
            forURL: url,
            gatewayStableID: url.mobileBrokerGatewayStableID ?? "")
        {
            self.setValue(value, forHTTPHeaderField: field)
        }
    }
}
