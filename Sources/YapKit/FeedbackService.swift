// FeedbackService.swift
// Handles submission of feedback to the API

import Foundation

/// Service for submitting feedback to your API.
public actor FeedbackService {
    private let config: FeedbackConfig
    private let session: URLSession
    
    /// Creates a new feedback service.
    /// - Parameters:
    ///   - config: Configuration for the feedback API
    ///   - session: URLSession to use for requests (defaults to shared)
    public init(config: FeedbackConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }
    
    /// Submits feedback to the API.
    /// - Parameters:
    ///   - type: The type of feedback being submitted
    ///   - message: The feedback message
    ///   - email: Optional contact email (stored privately, not exposed on GitHub)
    ///   - deviceInfo: Device metadata (auto-collected if nil)
    /// - Returns: The response from the server
    /// - Throws: `FeedbackError` if submission fails
    @MainActor
    public func submit(
        type: FeedbackType? = nil,
        message: String,
        email: String? = nil,
        deviceInfo: DeviceInfo? = nil
    ) async throws -> FeedbackResponse {
        let info = deviceInfo ?? DeviceInfo.current

        let payload = FeedbackPayload(
            type: type,
            message: message,
            email: email,
            deviceInfo: info
        )
        
        var request = URLRequest(url: config.feedbackURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FeedbackError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to extract error message from response
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw FeedbackError.serverError(errorResponse.error)
            }
            throw FeedbackError.httpError(statusCode: httpResponse.statusCode)
        }
        
        do {
            return try JSONDecoder().decode(FeedbackResponse.self, from: data)
        } catch {
            throw FeedbackError.decodingError(error)
        }
    }
}

// MARK: - Request/Response Types

/// The type of feedback being submitted.
public enum FeedbackType: String, CaseIterable, Codable, Sendable {
    case incorrectBehavior = "incorrect_behavior"
    case crash = "crash"
    case slowUnresponsive = "slow_unresponsive"
    case suggestion = "suggestion"

    /// Human-readable label for display in the UI.
    public var label: String {
        switch self {
        case .incorrectBehavior:
            return "Incorrect/unexpected behaviour"
        case .crash:
            return "Application crash"
        case .slowUnresponsive:
            return "Application slow/unresponsive"
        case .suggestion:
            return "Suggestion"
        }
    }
}

struct FeedbackPayload: Encodable {
    let type: FeedbackType?
    let message: String
    let email: String?
    let deviceInfo: DeviceInfo
}

/// Response from a successful feedback submission.
public struct FeedbackResponse: Decodable, Sendable {
    /// Whether the submission was successful
    public let success: Bool
    
    /// Unique identifier for this feedback
    public let feedbackId: String
    
    /// URL to the created GitHub issue (if created)
    public let githubIssue: String?
}

struct ErrorResponse: Decodable {
    let error: String
}

// MARK: - Errors

/// Errors that can occur during feedback submission.
public enum FeedbackError: LocalizedError, Sendable {
    case invalidResponse
    case httpError(statusCode: Int)
    case serverError(String)
    case decodingError(Error)
    case networkError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Received an invalid response from the server."
        case .httpError(let statusCode):
            return "Server returned an error (HTTP \(statusCode))."
        case .serverError(let message):
            return message
        case .decodingError:
            return "Failed to process the server response."
        case .networkError(let error):
            return error.localizedDescription
        }
    }
}
