// AttachmentUploader.swift
// Handles uploading attachments to Supabase Storage via signed URLs

import Foundation

/// Progress information for attachment uploads.
public struct UploadProgress: Sendable {
    /// Index of the attachment being uploaded (0-based).
    public let attachmentIndex: Int

    /// Total number of attachments.
    public let totalAttachments: Int

    /// Bytes uploaded for the current attachment.
    public let bytesUploaded: Int64

    /// Total bytes for the current attachment.
    public let totalBytes: Int64

    /// Overall progress across all attachments (0.0 to 1.0).
    public var overallProgress: Double {
        let completedAttachments = Double(attachmentIndex)
        let currentProgress = totalBytes > 0 ? Double(bytesUploaded) / Double(totalBytes) : 0
        return (completedAttachments + currentProgress) / Double(totalAttachments)
    }

    /// Progress for the current attachment (0.0 to 1.0).
    public var currentAttachmentProgress: Double {
        totalBytes > 0 ? Double(bytesUploaded) / Double(totalBytes) : 0
    }
}

/// Errors that can occur during attachment upload.
public enum AttachmentUploadError: LocalizedError, Sendable {
    case failedToGetUploadUrls(String)
    case uploadFailed(fileName: String, statusCode: Int)
    case networkError(Error)

    public var errorDescription: String? {
        switch self {
        case .failedToGetUploadUrls(let message):
            return "Failed to get upload URLs: \(message)"
        case .uploadFailed(let fileName, let statusCode):
            return "Failed to upload \"\(fileName)\" (HTTP \(statusCode))."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

/// Service for uploading attachments to the feedback backend.
public actor AttachmentUploader {
    private let config: FeedbackConfig
    private let session: URLSession

    /// Callback for progress updates.
    public typealias ProgressHandler = @Sendable (UploadProgress) -> Void

    public init(config: FeedbackConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    /// Uploads attachments and returns metadata for submission (internal use).
    @MainActor
    func upload(
        _ attachments: [FeedbackAttachment],
        progressHandler: ProgressHandler? = nil
    ) async throws -> [AttachmentSubmission] {
        guard !attachments.isEmpty else { return [] }

        // 1. Validate attachments locally
        try validateAttachments(attachments)

        // 2. Request signed upload URLs from backend
        let uploadUrls = try await requestUploadUrls(for: attachments)

        // 3. Upload each file to Supabase Storage
        var submissions: [AttachmentSubmission] = []

        for (index, attachment) in attachments.enumerated() {
            let uploadUrl = uploadUrls[index]

            // Report initial progress for this attachment
            progressHandler?(UploadProgress(
                attachmentIndex: index,
                totalAttachments: attachments.count,
                bytesUploaded: 0,
                totalBytes: Int64(attachment.fileSize)
            ))

            // Upload the file
            try await uploadFile(
                data: attachment.data,
                to: uploadUrl.signedUrl,
                mimeType: attachment.mimeType,
                fileName: attachment.fileName
            )

            // Report completion
            progressHandler?(UploadProgress(
                attachmentIndex: index,
                totalAttachments: attachments.count,
                bytesUploaded: Int64(attachment.fileSize),
                totalBytes: Int64(attachment.fileSize)
            ))

            // Build submission metadata
            submissions.append(AttachmentSubmission(
                storagePath: uploadUrl.storagePath,
                fileName: attachment.fileName,
                fileSize: attachment.fileSize,
                mimeType: attachment.mimeType,
                width: attachment.width,
                height: attachment.height,
                durationSeconds: attachment.durationSeconds
            ))
        }

        return submissions
    }

    // MARK: - Private Methods

    private func requestUploadUrls(for attachments: [FeedbackAttachment]) async throws -> [UploadUrl] {
        let url = config.apiBaseURL.appendingPathComponent("api/feedback/upload-url")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        let requestBody = [
            "attachments": attachments.map { attachment in
                AttachmentUploadRequest(
                    fileName: attachment.fileName,
                    fileSize: attachment.fileSize,
                    mimeType: attachment.mimeType,
                    width: attachment.width,
                    height: attachment.height,
                    durationSeconds: attachment.durationSeconds
                )
            }
        ]

        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AttachmentUploadError.failedToGetUploadUrls("Invalid response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw AttachmentUploadError.failedToGetUploadUrls(errorResponse.error)
            }
            throw AttachmentUploadError.failedToGetUploadUrls("HTTP \(httpResponse.statusCode)")
        }

        let urlResponse = try JSONDecoder().decode(UploadUrlResponse.self, from: data)
        return urlResponse.uploadUrls
    }

    private func uploadFile(
        data: Data,
        to urlString: String,
        mimeType: String,
        fileName: String
    ) async throws {
        guard let url = URL(string: urlString) else {
            throw AttachmentUploadError.uploadFailed(fileName: fileName, statusCode: 0)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(mimeType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AttachmentUploadError.uploadFailed(fileName: fileName, statusCode: 0)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw AttachmentUploadError.uploadFailed(fileName: fileName, statusCode: httpResponse.statusCode)
        }
    }
}
