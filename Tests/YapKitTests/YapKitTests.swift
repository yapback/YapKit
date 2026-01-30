import XCTest
@testable import YapKit

final class YapKitTests: XCTestCase {

    func testConfigInitialization() {
        let config = FeedbackConfig(
            apiKey: "yb_live_test123",
            apiBaseURL: "https://example.com"
        )

        XCTAssertEqual(config.apiKey, "yb_live_test123")
        XCTAssertEqual(config.apiBaseURL.absoluteString, "https://example.com")
        XCTAssertEqual(config.feedbackURL.absoluteString, "https://example.com/api/feedback")
    }

    func testConfigWithDefaultURL() {
        let config = FeedbackConfig(apiKey: "yb_live_test123")

        XCTAssertEqual(config.apiBaseURL.absoluteString, "https://yapback.dev")
    }

    func testConfigWithTrailingSlash() {
        let config = FeedbackConfig(
            apiKey: "yb_live_test123",
            apiBaseURL: "https://example.com/"
        )

        // URL should handle trailing slash gracefully
        XCTAssertTrue(config.feedbackURL.absoluteString.contains("api/feedback"))
    }

    func testDeviceInfoEncoding() throws {
        let deviceInfo = DeviceInfo(
            model: "iPhone15,2",
            osVersion: "iOS 17.4",
            appVersion: "1.2.3",
            buildNumber: "42",
            locale: "en_GB"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(deviceInfo)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["model"] as? String, "iPhone15,2")
        XCTAssertEqual(json["osVersion"] as? String, "iOS 17.4")
        XCTAssertEqual(json["appVersion"] as? String, "1.2.3")
        XCTAssertEqual(json["buildNumber"] as? String, "42")
        XCTAssertEqual(json["locale"] as? String, "en_GB")
    }

    func testFeedbackResponseDecoding() throws {
        let json = """
        {
            "success": true,
            "feedbackId": "abc-123",
            "githubIssue": "https://github.com/user/repo/issues/42"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(FeedbackResponse.self, from: json)

        XCTAssertTrue(response.success)
        XCTAssertEqual(response.feedbackId, "abc-123")
        XCTAssertEqual(response.githubIssue, "https://github.com/user/repo/issues/42")
    }

    func testFeedbackResponseWithoutGitHubIssue() throws {
        let json = """
        {
            "success": true,
            "feedbackId": "abc-123",
            "githubIssue": null
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(FeedbackResponse.self, from: json)

        XCTAssertTrue(response.success)
        XCTAssertNil(response.githubIssue)
    }

    func testFeedbackErrorDescriptions() {
        XCTAssertNotNil(FeedbackError.invalidResponse.errorDescription)
        XCTAssertNotNil(FeedbackError.httpError(statusCode: 500).errorDescription)
        XCTAssertNotNil(FeedbackError.serverError("Test error").errorDescription)

        XCTAssertTrue(
            FeedbackError.httpError(statusCode: 404)
                .errorDescription!
                .contains("404")
        )
    }
}
