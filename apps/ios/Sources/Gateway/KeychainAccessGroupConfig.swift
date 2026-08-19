//
//  KeychainAccessGroupConfig.swift
//
//  Created for OpenClaw mobile authentication
//

import Foundation
import Security

/// Configuration for Keychain access group sharing between app and extension
public enum KeychainAccessGroupConfig {
    /// The Keychain access group identifier
    /// This must match the value in the entitlements files:
    /// - OpenClaw.entitlements
    /// - OpenClawShareExtension.entitlements
    /// Both use $(OPENCLAW_ACTIVE_APP_GROUP_ID) which is set in the build settings
    public static var accessGroup: String? {
        // Try to get from Info.plist or build settings
        // This is set via $(OPENCLAW_ACTIVE_APP_GROUP_ID) in the entitlements
        // For now, we'll use a computed property that can be configured

        // In production, this should be set via build configuration
        // For development, you can set it in the app's Info.plist or xcconfig

        // Check if we have a value from build settings
        if let groupID = Bundle.main.object(forInfoDictionaryKey: "OPENCLAW_ACTIVE_APP_GROUP_ID") as? String {
            return groupID
        }

        // Fallback to nil - access group won't be used
        return nil
    }

    /// Whether Keychain sharing is configured
    public static var isConfigured: Bool {
        accessGroup != nil
    }

    /// Creates a MobileBrokerSessionStore with the configured access group
    public static func createSessionStore() -> MobileBrokerSessionStore {
        MobileBrokerSessionStore(accessGroup: self.accessGroup)
    }
}

// MARK: - Keychain Constants

/// Constants for Keychain configuration
public enum KeychainConstants {
    /// The service name for Keychain items
    public static let serviceName = "com.openclaw.service"

    /// Prefix for mobile broker session keys
    public static let mobileBrokerSessionPrefix = "com.openclaw.mobileBrokerSession."
}
