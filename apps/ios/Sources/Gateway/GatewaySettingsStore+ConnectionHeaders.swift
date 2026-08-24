//
//  GatewaySettingsStore+ConnectionHeaders.swift
//
//  Created for OpenClaw mobile authentication
//

import Foundation

extension GatewaySettingsStore {
    /// Extra headers for the real Gateway WebSocket upgrade request: the
    /// operator-configured custom headers merged with the mobile-broker
    /// Authorization header (when this route uses the broker). This is the
    /// canonical `extraHeadersProvider` body for every real connect call site
    /// (GatewayNodeSession.connect via NodeAppModel and GatewayOperatorFleet).
    static func loadConnectionHeaders(url: URL, gatewayStableID: String) -> [String: String] {
        self.loadGatewayCustomHeaders(gatewayStableID: gatewayStableID)
            .merging(
                KeychainAccessGroupConfig.createSessionStore()
                    .authorizationHeaders(forURL: url, gatewayStableID: gatewayStableID)) { _, new in new }
    }
}
