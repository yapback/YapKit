// VideoValidator.swift
// Validates video duration and extracts metadata using AVFoundation

import AVFoundation
import Foundation

/// Errors that can occur during video validation.
public enum VideoValidationError: LocalizedError, Sendable {
    case invalidVideo
    case durationTooLong(duration: Double, maxDuration: Double)
    case couldNotLoadAsset

    public var errorDescription: String? {
        switch self {
        case .invalidVideo:
            return "The selected file is not a valid video."
        case .durationTooLong(let duration, let maxDuration):
            return "Video duration (\(Int(duration))s) exceeds maximum (\(Int(maxDuration))s)."
        case .couldNotLoadAsset:
            return "Could not load video for validation."
        }
    }
}

/// Result of video validation containing metadata.
public struct VideoMetadata: Sendable {
    public let duration: Double
    public let width: Int
    public let height: Int
    public let fileSize: Int
}

/// Validates video files for feedback attachments.
public struct VideoValidator: Sendable {
    private let maxDuration: Double

    /// Creates a new validator with specified limits.
    /// - Parameter maxDuration: Maximum allowed duration in seconds (default: 60)
    public init(maxDuration: Double = Double(AttachmentLimits.maxVideoDuration)) {
        self.maxDuration = maxDuration
    }

    /// Validates a video at the given URL.
    /// - Parameter url: File URL of the video to validate
    /// - Returns: Metadata if valid
    /// - Throws: `VideoValidationError` if validation fails
    public func validate(url: URL) async throws -> VideoMetadata {
        let asset = AVURLAsset(url: url)

        // Load duration
        let duration: CMTime
        do {
            duration = try await asset.load(.duration)
        } catch {
            throw VideoValidationError.couldNotLoadAsset
        }

        let durationSeconds = CMTimeGetSeconds(duration)

        guard durationSeconds.isFinite else {
            throw VideoValidationError.invalidVideo
        }

        // Check duration limit
        if durationSeconds > maxDuration {
            throw VideoValidationError.durationTooLong(
                duration: durationSeconds,
                maxDuration: maxDuration
            )
        }

        // Get video dimensions
        var width = 0
        var height = 0

        do {
            let tracks = try await asset.loadTracks(withMediaType: .video)
            if let videoTrack = tracks.first {
                let naturalSize = try await videoTrack.load(.naturalSize)
                let transform = try await videoTrack.load(.preferredTransform)

                // Apply transform to get actual display dimensions
                let transformedSize = naturalSize.applying(transform)
                width = Int(abs(transformedSize.width))
                height = Int(abs(transformedSize.height))
            }
        } catch {
            // Dimensions are optional, continue without them
        }

        // Get file size
        let fileSize: Int
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            fileSize = (attributes[.size] as? Int) ?? 0
        } catch {
            fileSize = 0
        }

        return VideoMetadata(
            duration: durationSeconds,
            width: width,
            height: height,
            fileSize: fileSize
        )
    }

    /// Validates video data by writing to a temporary file.
    /// - Parameters:
    ///   - data: Video data to validate
    ///   - mimeType: MIME type of the video
    /// - Returns: Metadata if valid
    /// - Throws: `VideoValidationError` if validation fails
    public func validate(data: Data, mimeType: String) async throws -> VideoMetadata {
        // Determine file extension from mime type
        let fileExtension: String
        switch mimeType {
        case "video/mp4":
            fileExtension = "mp4"
        case "video/quicktime":
            fileExtension = "mov"
        case "video/webm":
            fileExtension = "webm"
        default:
            fileExtension = "mp4"
        }

        // Write to temp file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        try data.write(to: tempURL)

        return try await validate(url: tempURL)
    }
}
