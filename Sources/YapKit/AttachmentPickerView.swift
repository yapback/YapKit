// AttachmentPickerView.swift
// SwiftUI view for selecting images and videos using PhotosPicker

import PhotosUI
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// View state for attachment processing.
public enum AttachmentLoadingState: Equatable, Sendable {
    case idle
    case loading(Int, Int)
    case error(String)
}

/// View for displaying and managing selected attachments.
public struct AttachmentPickerView: View {
    @Binding var attachments: [FeedbackAttachment]
    @Binding var loadingState: AttachmentLoadingState

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var loadedData: [String: FeedbackAttachment] = [:]

    private let maxAttachments: Int

    public init(
        attachments: Binding<[FeedbackAttachment]>,
        loadingState: Binding<AttachmentLoadingState>,
        maxAttachments: Int = AttachmentLimits.maxAttachments
    ) {
        self._attachments = attachments
        self._loadingState = loadingState
        self.maxAttachments = maxAttachments
    }

    public var body: some View {
        Section {
					PhotosPicker(
						selection: $selectedItems,
						maxSelectionCount: maxAttachments,
						selectionBehavior: .ordered,
						matching: .any(of: [.videos, .images]),
						photoLibrary: .shared()
					) {
						Label("Add attachments", systemImage: "paperclip")
					}
					
					if case .error(let message) = loadingState {
						Label(message, systemImage: "exclamationmark.triangle")
							.font(.caption)
							.foregroundStyle(.red)
					}
					
           
					if !selectedItems.isEmpty {
							LazyVGrid(columns: [
									GridItem(.adaptive(minimum: 80, maximum: 100), spacing: 8)
							], spacing: 8) {
									ForEach(selectedItems, id: \.itemIdentifier) { item in
											ItemThumbnail(
													item: item,
													attachment: item.itemIdentifier.flatMap { loadedData[$0] },
													onRemove: { selectedItems.removeAll { $0.itemIdentifier == item.itemIdentifier } },
													onLoaded: { attachment in
															guard let id = item.itemIdentifier else { return }
															loadedData[id] = attachment
															syncAttachments()
													},
													onError: { error in
															selectedItems.removeAll { $0.itemIdentifier == item.itemIdentifier }
															loadingState = .error(error.localizedDescription)
													}
											)
									}
							}
							.listRowInsets(.init(top: 12, leading: 12, bottom: 12, trailing: 12))
					}
        } header: {
					Text("Attachments")
        } footer: {
					Text("\(selectedItems.count)/\(maxAttachments) attachments")
        }
        .onChange(of: selectedItems) { _ in
            // Clean up cached data for deselected items
            let currentIds = Set(selectedItems.compactMap { $0.itemIdentifier })
            let hadRemovals = loadedData.keys.contains { !currentIds.contains($0) }
            loadedData = loadedData.filter { currentIds.contains($0.key) }
            if hadRemovals {
                syncAttachments()
            }
        }
    }

    private func syncAttachments() {
        attachments = selectedItems.compactMap { item in
            guard let id = item.itemIdentifier else { return nil }
            return loadedData[id]
        }
    }
}

// MARK: - Item Thumbnail (handles loading via .task)

private struct ItemThumbnail: View {
    let item: PhotosPickerItem
    let attachment: FeedbackAttachment?
    let onRemove: () -> Void
    let onLoaded: (FeedbackAttachment) -> Void
    let onError: (Error) -> Void

    var body: some View {
        Group {
            if let attachment {
                AttachmentThumbnail(attachment: attachment, onRemove: onRemove)
            } else {
                LoadingThumbnail()
            }
        }
        .task(id: item.itemIdentifier) {
            guard attachment == nil else { return }
            do {
                let loaded = try await loadAttachment(from: item)
                onLoaded(loaded)
            } catch {
                onError(error)
            }
        }
    }

    private func loadAttachment(from item: PhotosPickerItem) async throws -> FeedbackAttachment {
        // Try video first
        if let movie = try await item.loadTransferable(type: VideoTransferable.self) {
            return try await processVideo(movie)
        }

        // Try image
        if let imageData = try await item.loadTransferable(type: Data.self) {
            return try processImage(imageData)
        }

        throw AttachmentValidationError.unsupportedFileType(fileName: "unknown", mimeType: "unknown")
    }

    private func processVideo(_ video: VideoTransferable) async throws -> FeedbackAttachment {
        let validator = VideoValidator()
        let metadata = try await validator.validate(url: video.url)

        if metadata.duration > Double(AttachmentLimits.maxVideoDuration) {
            throw AttachmentValidationError.videoDurationTooLong(
                fileName: video.url.lastPathComponent,
                maxDuration: AttachmentLimits.maxVideoDuration
            )
        }

        if metadata.fileSize > AttachmentLimits.maxVideoSize {
            throw AttachmentValidationError.fileTooLarge(
                fileName: video.url.lastPathComponent,
                maxSize: AttachmentLimits.maxVideoSize
            )
        }

        let data = try Data(contentsOf: video.url)
        let mimeType = mimeTypeForExtension(video.url.pathExtension)

        return FeedbackAttachment(
            videoData: data,
            fileName: video.url.lastPathComponent,
            mimeType: mimeType,
            width: metadata.width,
            height: metadata.height,
            durationSeconds: metadata.duration
        )
    }

    private func processImage(_ data: Data) throws -> FeedbackAttachment {
        if data.count > AttachmentLimits.maxImageSize {
            throw AttachmentValidationError.fileTooLarge(
                fileName: "image",
                maxSize: AttachmentLimits.maxImageSize
            )
        }

        let (mimeType, width, height) = detectImageMetadata(data)
        let fileExtension = extensionForMimeType(mimeType)
        let fileName = "\(UUID().uuidString).\(fileExtension)"

        return FeedbackAttachment(
            imageData: data,
            fileName: fileName,
            mimeType: mimeType,
            width: width,
            height: height
        )
    }
}

// MARK: - Loading Thumbnail

private struct LoadingThumbnail: View {
    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay { ProgressView() }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Attachment Thumbnail

private struct AttachmentThumbnail: View {
    let attachment: FeedbackAttachment
    let onRemove: () -> Void

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                Group {
                    if let image = thumbnailImage {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay {
                                Image(systemName: attachment.isVideo ? "video" : "photo")
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                if attachment.isVideo, let duration = attachment.durationSeconds {
                    Text(formatDuration(duration))
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(4)
                }
            }
            .overlay(alignment: .topTrailing) {
                Button("Remove", systemImage: "xmark.circle", action: onRemove)
                    .buttonStyle(.plain)
                    .background { Circle().fill(.thinMaterial) }
                    .controlSize(.mini)
                    .labelStyle(.iconOnly)
                    .padding(4)
            }
    }

    @MainActor
    private var thumbnailImage: Image? {
        guard attachment.isImage else { return nil }
        #if canImport(UIKit)
        guard let uiImage = UIImage(data: attachment.data) else { return nil }
        return Image(uiImage: uiImage)
        #elseif canImport(AppKit)
        guard let nsImage = NSImage(data: attachment.data) else { return nil }
        return Image(nsImage: nsImage)
        #else
        return nil
        #endif
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Video Transferable

struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return Self(url: tempURL)
        }
    }
}

// MARK: - Helpers

private func detectImageMetadata(_ data: Data) -> (mimeType: String, width: Int, height: Int) {
    var mimeType = "image/jpeg"
    var width = 0
    var height = 0

    if data.starts(with: [0xFF, 0xD8, 0xFF]) {
        mimeType = "image/jpeg"
    } else if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
        mimeType = "image/png"
    } else if data.count >= 12 {
        let header = [UInt8](data.prefix(12))
        if header[4...7] == [0x66, 0x74, 0x79, 0x70] {
            mimeType = "image/heic"
        }
        if header[0...3] == [0x52, 0x49, 0x46, 0x46] && header[8...11] == [0x57, 0x45, 0x42, 0x50] {
            mimeType = "image/webp"
        }
    }

    #if canImport(UIKit)
    if let image = UIImage(data: data) {
        width = Int(image.size.width * image.scale)
        height = Int(image.size.height * image.scale)
    }
    #elseif canImport(AppKit)
    if let image = NSImage(data: data) {
        width = Int(image.size.width)
        height = Int(image.size.height)
    }
    #endif

    return (mimeType, width, height)
}

private func mimeTypeForExtension(_ ext: String) -> String {
    switch ext.lowercased() {
    case "mp4", "m4v": return "video/mp4"
    case "mov": return "video/quicktime"
    case "webm": return "video/webm"
    default: return "video/mp4"
    }
}

private func extensionForMimeType(_ mimeType: String) -> String {
    switch mimeType {
    case "image/jpeg": return "jpg"
    case "image/png": return "png"
    case "image/heic": return "heic"
    case "image/webp": return "webp"
    default: return "jpg"
    }
}

extension Data {
    func starts(with bytes: [UInt8]) -> Bool {
        guard count >= bytes.count else { return false }
        return prefix(bytes.count).elementsEqual(bytes)
    }
}
