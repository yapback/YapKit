// YapKit.swift
// Public API for YapKit

/// YapKit provides a simple way to collect user feedback from your iOS and macOS apps.
///
/// ## Quick Start
///
/// 1. Create a configuration:
/// ```swift
/// let config = FeedbackConfig(
///     appId: "my-app",
///     apiBaseURL: "https://mysite.vercel.app"
/// )
/// ```
///
/// 2. Present the feedback view:
/// ```swift
/// struct SettingsView: View {
///     @State private var showFeedback = false
///
///     var body: some View {
///         Button("Send Feedback") {
///             showFeedback = true
///         }
///         .feedbackSheet(isPresented: $showFeedback, config: config)
///     }
/// }
/// ```
///
/// ## Features
///
/// - Simple SwiftUI integration via sheet modifier
/// - Automatic device info collection (model, OS, app version)
/// - Optional email field for follow-ups (stored privately, never exposed on GitHub)
/// - Success animation and error handling built-in
/// - Works on iOS and macOS

// Re-export all public types
@_exported import struct YapKit.FeedbackConfig
@_exported import struct YapKit.FeedbackView
@_exported import actor YapKit.FeedbackService
@_exported import struct YapKit.FeedbackResponse
@_exported import enum YapKit.FeedbackError
@_exported import struct YapKit.DeviceInfo
