// Attachment.swift
// Models for feedback attachments

import Foundation
import UniformTypeIdentifiers

/// Represents an attachment to be uploaded with feedback.
public struct FeedbackAttachment: Sendable, Identifiable {
    public let id: UUID
    public let data: Data
    public let fileName: String
    public let mimeType: String
    public let width: Int?
    public let height: Int?
    public let durationSeconds: Double?

    /// Creates a new attachment from image data.
    /// - Parameters:
    ///   - id: Optional identifier (defaults to new UUID)
    ///   - data: The image data
    ///   - fileName: Original file name
    ///   - mimeType: MIME type (e.g., "image/jpeg")
    ///   - width: Image width in pixels
    ///   - height: Image height in pixels
    public init(
        id: UUID = UUID(),
        imageData data: Data,
        fileName: String,
        mimeType: String,
        width: Int,
        height: Int
    ) {
        self.id = id
        self.data = data
        self.fileName = fileName
        self.mimeType = mimeType
        self.width = width
        self.height = height
        self.durationSeconds = nil
    }

    /// Creates a new attachment from video data.
    /// - Parameters:
    ///   - id: Optional identifier (defaults to new UUID)
    ///   - data: The video data
    ///   - fileName: Original file name
    ///   - mimeType: MIME type (e.g., "video/mp4")
    ///   - width: Video width in pixels
    ///   - height: Video height in pixels
    ///   - durationSeconds: Video duration in seconds
    public init(
        id: UUID = UUID(),
        videoData data: Data,
        fileName: String,
        mimeType: String,
        width: Int,
        height: Int,
        durationSeconds: Double
    ) {
        self.id = id
        self.data = data
        self.fileName = fileName
        self.mimeType = mimeType
        self.width = width
        self.height = height
        self.durationSeconds = durationSeconds
    }

    /// File size in bytes.
    public var fileSize: Int {
        data.count
    }

    /// Whether this is a video attachment.
    public var isVideo: Bool {
        mimeType.hasPrefix("video/")
    }

    /// Whether this is an image attachment.
    public var isImage: Bool {
        mimeType.hasPrefix("image/")
    }
}

// MARK: - Metadata for API

/// Metadata sent to the server when requesting upload URLs.
struct AttachmentUploadRequest: Encodable {
    let fileName: String
    let fileSize: Int
    let mimeType: String
    let width: Int?
    let height: Int?
    let durationSeconds: Double?
}

/// Metadata sent with feedback submission after upload.
struct AttachmentSubmission: Encodable {
    let storagePath: String
    let fileName: String
    let fileSize: Int
    let mimeType: String
    let width: Int?
    let height: Int?
    let durationSeconds: Double?
}

// MARK: - API Response Types

struct UploadUrlResponse: Decodable {
    let success: Bool
    let uploadUrls: [UploadUrl]
    let limits: UploadLimits
}

struct UploadUrl: Decodable {
    let storagePath: String
    let signedUrl: String
    let token: String
}

struct UploadLimits: Decodable {
    let maxImageSize: Int
    let maxVideoSize: Int
    let maxVideoDuration: Int
    let maxAttachments: Int
}

// MARK: - Validation

/// Errors that can occur during attachment validation.
public enum AttachmentValidationError: LocalizedError, Sendable {
    case tooManyAttachments(max: Int)
    case fileTooLarge(fileName: String, maxSize: Int)
    case videoDurationTooLong(fileName: String, maxDuration: Int)
    case unsupportedFileType(fileName: String, mimeType: String)

    public var errorDescription: String? {
        switch self {
        case .tooManyAttachments(let max):
            return "Maximum \(max) attachments allowed."
        case .fileTooLarge(let fileName, let maxSize):
            let maxMB = maxSize / (1024 * 1024)
            return "\"\(fileName)\" exceeds the maximum size of \(maxMB) MB."
        case .videoDurationTooLong(let fileName, let maxDuration):
            return "\"\(fileName)\" exceeds the maximum duration of \(maxDuration) seconds."
        case .unsupportedFileType(let fileName, let mimeType):
            return "\"\(fileName)\" has an unsupported file type (\(mimeType))."
        }
    }
}

/// Validation limits for attachments.
public struct AttachmentLimits: Sendable {
    public static let maxImageSize = 10 * 1024 * 1024 // 10 MB
    public static let maxVideoSize = 50 * 1024 * 1024 // 50 MB
    public static let maxVideoDuration = 60 // seconds
    public static let maxAttachments = 5

    public static let allowedImageTypes = [
        "image/jpeg",
        "image/png",
        "image/heic",
        "image/webp",
    ]

    public static let allowedVideoTypes = [
        "video/mp4",
        "video/quicktime",
        "video/webm",
    ]

    public static var allowedMimeTypes: [String] {
        allowedImageTypes + allowedVideoTypes
    }
}

/// Validates attachments before upload.
public func validateAttachments(_ attachments: [FeedbackAttachment]) throws {
    if attachments.count > AttachmentLimits.maxAttachments {
        throw AttachmentValidationError.tooManyAttachments(max: AttachmentLimits.maxAttachments)
    }

    for attachment in attachments {
        // Validate mime type
        guard AttachmentLimits.allowedMimeTypes.contains(attachment.mimeType) else {
            throw AttachmentValidationError.unsupportedFileType(
                fileName: attachment.fileName,
                mimeType: attachment.mimeType
            )
        }

        // Validate file size
        let maxSize = attachment.isVideo
            ? AttachmentLimits.maxVideoSize
            : AttachmentLimits.maxImageSize

        if attachment.fileSize > maxSize {
            throw AttachmentValidationError.fileTooLarge(
                fileName: attachment.fileName,
                maxSize: maxSize
            )
        }

        // Validate video duration
        if attachment.isVideo {
            guard let duration = attachment.durationSeconds else {
                throw AttachmentValidationError.videoDurationTooLong(
                    fileName: attachment.fileName,
                    maxDuration: AttachmentLimits.maxVideoDuration
                )
            }

            if duration > Double(AttachmentLimits.maxVideoDuration) {
                throw AttachmentValidationError.videoDurationTooLong(
                    fileName: attachment.fileName,
                    maxDuration: AttachmentLimits.maxVideoDuration
                )
            }
        }
    }
}
