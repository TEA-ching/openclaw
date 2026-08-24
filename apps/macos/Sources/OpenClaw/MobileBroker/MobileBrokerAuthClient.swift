//
//  MobileBrokerAuthClient.swift
//
//  Created for OpenClaw mobile authentication
//

import Foundation

/// Client for communicating with the mobile authentication broker API
public final class MobileBrokerAuthClient: Sendable {
    // MARK: - Types

    /// Request for initiating device authorization
    public struct DeviceAuthorizationRequest: Codable, Sendable {
        // Empty for now - may add parameters later
    }

    /// Response from initiating device authorization
    public struct DeviceAuthorizationResponse: Codable, Sendable {
        public let transactionID: String
        public let userCode: String
        public let verificationURI: String
        public let expiresAt: Date
        public let pollAfterSeconds: Int

        enum CodingKeys: String, CodingKey {
            case transactionID = "transaction_id"
            case userCode = "user_code"
            case verificationURI = "verification_uri"
            case expiresAt = "expires_at"
            case pollAfterSeconds = "poll_after_seconds"
        }
    }

    /// Status of a device authorization
    public enum DeviceAuthorizationStatus: String, Codable, Sendable {
        case pending
        case slowDown = "slow_down"
        case denied
        case expired
        case approved
        case forbidden
    }

    /// Response from polling device authorization status
    public struct DeviceAuthorizationStatusResponse: Codable, Sendable {
        public let status: DeviceAuthorizationStatus
        public let accessToken: String?
        public let accessExpiresAt: Date?
        public let refreshToken: String?
        public let refreshExpiresAt: Date?
        public let subjectEmail: String?
        public let error: String?
        public let errorMessage: String?

        enum CodingKeys: String, CodingKey {
            case status
            case accessToken = "access_token"
            case accessExpiresAt = "access_expires_at"
            case refreshToken = "refresh_token"
            case refreshExpiresAt = "refresh_expires_at"
            case subjectEmail = "subject_email"
            case error
            case errorMessage = "error_message"
        }
    }

    /// Request for refreshing a session
    public struct RefreshSessionRequest: Codable, Sendable {
        public let refreshToken: String

        enum CodingKeys: String, CodingKey {
            case refreshToken = "refresh_token"
        }
    }

    /// Response from refreshing a session
    public struct RefreshSessionResponse: Codable, Sendable {
        public let accessToken: String
        public let accessExpiresAt: Date
        public let refreshToken: String
        public let refreshExpiresAt: Date

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case accessExpiresAt = "access_expires_at"
            case refreshToken = "refresh_token"
            case refreshExpiresAt = "refresh_expires_at"
        }
    }

    /// Error response from the broker
    public struct BrokerErrorResponse: Codable, LocalizedError, Sendable {
        public let error: String
        public let errorMessage: String?

        enum CodingKeys: String, CodingKey {
            case error
            case errorMessage = "error_message"
        }

        public var errorDescription: String? {
            if let message = errorMessage {
                return "\(self.error): \(message)"
            }
            return self.error
        }
    }

    // MARK: - Properties

    let config: MobileBrokerConfig
    private let urlSession: URLSession
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder

    // MARK: - Initialization

    /// Initialize with a configuration
    /// - Parameters:
    ///   - config: The mobile broker configuration
    ///   - urlSession: The URLSession to use (for dependency injection and testing)
    public init(config: MobileBrokerConfig, urlSession: URLSession = .shared) {
        self.config = config
        self.urlSession = urlSession

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.jsonDecoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.jsonEncoder = encoder
    }

    // MARK: - Device Authorization

    /// Initiates a new device authorization flow
    /// - Returns: The device authorization response with user code and verification URI
    /// - Throws: Network or broker error
    public func initiateDeviceAuthorization() async throws -> DeviceAuthorizationResponse {
        let url = self.config.baseURL.appendingPathComponent("v1/device-authorizations")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let error = try? self.jsonDecoder.decode(BrokerErrorResponse.self, from: data)
            throw error ?? URLError(.cannotParseResponse)
        }

        return try self.jsonDecoder.decode(DeviceAuthorizationResponse.self, from: data)
    }

    // MARK: - Poll Device Authorization

    /// Polls the status of a device authorization
    /// - Parameter transactionID: The transaction ID to poll
    /// - Returns: The status response, which may contain tokens if approved
    /// - Throws: Network or broker error
    public func pollDeviceAuthorization(transactionID: String) async throws -> DeviceAuthorizationStatusResponse {
        let url = self.config.baseURL
            .appendingPathComponent("v1/device-authorizations")
            .appendingPathComponent(transactionID)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        // Handle terminal statuses (approved, denied, expired, forbidden)
        if httpResponse.statusCode == 200 {
            return try self.jsonDecoder.decode(DeviceAuthorizationStatusResponse.self, from: data)
        }

        // Handle errors
        if (400...599).contains(httpResponse.statusCode) {
            let error = try? self.jsonDecoder.decode(BrokerErrorResponse.self, from: data)
            throw error ?? URLError(.cannotParseResponse)
        }

        throw URLError(.badServerResponse)
    }

    // MARK: - Refresh Session

    /// Refreshes an access token using a refresh token
    /// - Parameter refreshToken: The refresh token to use
    /// - Returns: The new access and refresh tokens
    /// - Throws: Network or broker error
    public func refreshSession(refreshToken: String) async throws -> RefreshSessionResponse {
        let url = self.config.baseURL.appendingPathComponent("v1/sessions/refresh")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let requestBody = RefreshSessionRequest(refreshToken: refreshToken)
        request.httpBody = try self.jsonEncoder.encode(requestBody)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let error = try? self.jsonDecoder.decode(BrokerErrorResponse.self, from: data)
            throw error ?? URLError(.cannotParseResponse)
        }

        return try self.jsonDecoder.decode(RefreshSessionResponse.self, from: data)
    }

    // MARK: - Revoke Session

    /// Revokes the current session
    /// - Parameter accessToken: The access token to revoke
    /// - Throws: Network or broker error
    public func revokeCurrentSession(accessToken: String) async throws {
        let url = self.config.baseURL.appendingPathComponent("v1/sessions/current")

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        // 204 No Content is expected for successful revocation
        guard httpResponse.statusCode == 204 || httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }

    // MARK: - Device Flow Management

    /// Performs the complete device flow, polling until completion or timeout
    /// - Parameters:
    ///   - initialPollInterval: Initial polling interval in seconds (defaults to 5)
    ///   - timeout: Maximum time to wait for completion in seconds (defaults to 600 = 10 minutes)
    /// - Returns: The session tokens if approved
    /// - Throws: Network, broker, or timeout error
    public func performDeviceFlow(
        initialPollInterval: TimeInterval = 5,
        timeout: TimeInterval = 600) async throws -> MobileBrokerSessionStore.Session
    {
        // Initiate device flow
        let authResponse = try await initiateDeviceAuthorization()

        let startTime = Date()
        var currentPollInterval = TimeInterval(authResponse.pollAfterSeconds)

        while Date().timeIntervalSince(startTime) < timeout {
            // Wait for the poll interval
            try await Task.sleep(nanoseconds: UInt64(currentPollInterval * 1_000_000_000))

            // Poll for status
            let statusResponse = try await pollDeviceAuthorization(
                transactionID: authResponse.transactionID)

            switch statusResponse.status {
            case .approved:
                guard let accessToken = statusResponse.accessToken,
                      let refreshToken = statusResponse.refreshToken,
                      let accessExpiresAt = statusResponse.accessExpiresAt,
                      let refreshExpiresAt = statusResponse.refreshExpiresAt,
                      let subjectEmail = statusResponse.subjectEmail
                else {
                    throw URLError(.cannotParseResponse)
                }

                return MobileBrokerSessionStore.Session(
                    accessToken: accessToken,
                    refreshToken: refreshToken,
                    accessExpiresAt: accessExpiresAt,
                    refreshExpiresAt: refreshExpiresAt,
                    brokerDeviceID: subjectEmail,
                    brokerHostname: self.config.hostname)

            case .slowDown:
                // Increase poll interval by 50%
                currentPollInterval *= 1.5
                continue

            case .denied, .forbidden, .expired:
                let errorMessage = statusResponse.errorMessage ?? statusResponse.error ?? "Unknown error"
                throw BrokerErrorResponse(error: statusResponse.status.rawValue, errorMessage: errorMessage)

            case .pending:
                // Continue polling with current interval
                continue
            }
        }

        throw URLError(.timedOut)
    }
}
