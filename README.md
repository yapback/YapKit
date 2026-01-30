# YapKit

A lightweight Swift package for collecting user feedback in iOS and macOS apps.

## Features

- Simple SwiftUI integration via sheet modifier
- Automatic device info collection (model, OS, app version, locale)
- Optional email field for follow-ups (stored privately, never exposed publicly)
- Success animation and error handling built-in
- Works on iOS 16+ and macOS 13+

## Installation

### Swift Package Manager

Add YapKit to your project via Xcode:

1. File → Add Package Dependencies
2. Enter the repository URL: `https://github.com/yapback/YapKit`
3. Select your version requirements

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yapback/YapKit", from: "1.0.0")
]
```

## Setup

### 1. Get your API key

Sign up at [yapback.dev](https://yapback.dev), create an app, and copy your API key.

### 2. Create a configuration

```swift
import YapKit

// Define once, use across your app
extension FeedbackConfig {
    static let myApp = FeedbackConfig(
        apiKey: "yb_live_your_api_key_here"
    )
}
```

For self-hosted deployments, specify your API URL:

```swift
extension FeedbackConfig {
    static let myApp = FeedbackConfig(
        apiKey: "yb_live_your_api_key_here",
        apiBaseURL: "https://your-domain.com"
    )
}
```

## Usage

### Sheet modifier (recommended)

```swift
struct SettingsView: View {
    @State private var showFeedback = false

    var body: some View {
        Form {
            Button("Send Feedback") {
                showFeedback = true
            }
        }
        .feedbackSheet(isPresented: $showFeedback, config: .myApp)
    }
}
```

### Direct presentation

```swift
struct SettingsView: View {
    @State private var showFeedback = false

    var body: some View {
        Button("Send Feedback") {
            showFeedback = true
        }
        .sheet(isPresented: $showFeedback) {
            FeedbackView(config: .myApp)
        }
    }
}
```

### Programmatic submission

If you need to submit feedback without the UI:

```swift
let service = FeedbackService(config: .myApp)

do {
    let response = try await service.submit(
        message: "This is great!",
        email: "user@example.com"  // optional
    )
    print("Feedback submitted: \(response.feedbackId)")
} catch {
    print("Error: \(error.localizedDescription)")
}
```

## API Reference

### FeedbackConfig

```swift
FeedbackConfig(
    apiKey: String,       // Your API key from the dashboard (starts with "yb_live_")
    apiBaseURL: String    // Optional: defaults to "https://yapback.dev"
)
```

### FeedbackView

A SwiftUI view that presents a feedback form with:
- Multi-line message field
- Optional email field
- Automatic device info collection
- Submit button with loading state
- Success animation on completion

### FeedbackService

An actor for programmatic feedback submission:

```swift
func submit(
    message: String,
    email: String? = nil,
    deviceInfo: DeviceInfo? = nil  // Auto-collected if nil
) async throws -> FeedbackResponse
```

### DeviceInfo

Automatically collected metadata:
- `model`: Device identifier (e.g., "iPhone15,2")
- `osVersion`: OS name and version (e.g., "iOS 17.4")
- `appVersion`: Your app's version string
- `buildNumber`: Your app's build number
- `locale`: User's locale identifier

## Requirements

- iOS 16.0+ / macOS 13.0+
- Swift 5.9+
- Xcode 15.0+

## License

MIT
