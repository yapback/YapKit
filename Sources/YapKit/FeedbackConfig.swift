// FeedbackConfig.swift
// Configuration for the feedback service

import Foundation

/// Configuration for connecting to your feedback API.
public struct FeedbackConfig: Sendable {
    /// API key for authenticating with the feedback service
    public let apiKey: String

    /// Base URL for your feedback API (without trailing slash)
    public let apiBaseURL: URL

    /// Full URL for the feedback endpoint
    public var feedbackURL: URL {
        apiBaseURL.appendingPathComponent("api/feedback")
    }

    /// Creates a new feedback configuration.
    /// - Parameters:
    ///   - apiKey: Your API key from the Yapback dashboard (starts with "yb_live_")
    ///   - apiBaseURL: Base URL of the feedback service (e.g., "https://yapback.dev")
    public init(apiKey: String, apiBaseURL: String = "https://yapback.dev") {
        self.apiKey = apiKey
        self.apiBaseURL = URL(string: apiBaseURL)!
    }

    /// Creates a new feedback configuration with a URL.
    /// - Parameters:
    ///   - apiKey: Your API key from the YapKit dashboard
    ///   - apiBaseURL: Base URL of the feedback service
    public init(apiKey: String, apiBaseURL: URL) {
        self.apiKey = apiKey
        self.apiBaseURL = apiBaseURL
    }
}
