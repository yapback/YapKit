// FeedbackView.swift
// SwiftUI view for collecting and submitting feedback

import SwiftUI

/// A view for collecting user feedback.
///
/// Present this as a sheet from your settings or help menu:
/// ```swift
/// .sheet(isPresented: $showFeedback) {
///     FeedbackView(config: .myApp)
/// }
/// ```
///
/// Or use the convenience modifier:
/// ```swift
/// .feedbackSheet(isPresented: $showFeedback, config: .myApp)
/// ```
public struct FeedbackView: View {
	private let config: FeedbackConfig
	private let onDismiss: (() -> Void)?
	
	@Environment(\.dismiss) private var dismiss
	
	@State private var feedbackType: FeedbackType?
	@State private var message = ""
	@AppStorage("me.daneden.YapKit.Feedback.email") private var email = ""
	@AppStorage("me.daneden.YapKit.Feedback.rememberEmail") private var rememberEmail = false
	@State private var isSubmitting = false
	@State private var submissionState: SubmissionState = .idle
	
	@FocusState private var focusedField: Field?
	
	private enum Field {
		case message, email
	}
	
	private enum SubmissionState: Equatable {
		case idle
		case submitting
		case success
		case error(String)
	}
	
	/// Creates a new feedback view.
	/// - Parameters:
	///   - config: Configuration for the feedback API
	///   - onDismiss: Optional callback when the view is dismissed
	public init(config: FeedbackConfig, onDismiss: (() -> Void)? = nil) {
		self.config = config
		self.onDismiss = onDismiss
	}
	
	public var body: some View {
		NavigationStack {
			Form {
				Section("What type of feedback are you reporting?") {
					Picker("Feedback type", selection: $feedbackType.animation()) {
						Text("Other")
							.disabled(true)
							.tag(Optional<FeedbackType>.none)
						
						ForEach(FeedbackType.allCases, id: \.self) { type in
							Text(type.label).tag(type)
						}
					}
				}
				
				Section {
					TextField("What's on your mind?", text: $message, axis: .vertical)
						.lineLimit(5...10)
						.focused($focusedField, equals: .message)
				} header: {
					Text("Details")
				} footer: {
					VStack(alignment: .leading) {
						if feedbackType != .suggestion {
							Text("Please describe the issue and what steps we can take to reproduce it")
						}
					}
				}
				
				Section {
					TextField("Email (optional)", text: $email.animation())
						#if os(iOS)
						.keyboardType(.emailAddress)
						.textInputAutocapitalization(.never)
						.textContentType(.emailAddress)
						#endif
						.autocorrectionDisabled()
						.focused($focusedField, equals: .email)
					
					Toggle(isOn: $rememberEmail) {
						Text("Remember email address")
					}
					.disabled(email.isEmpty)
				} footer: {
					Text("Provide a contact email so that we can follow up if needed")
				}
				
				if case .error(let message) = submissionState {
					Section {
						Label(message, systemImage: "exclamationmark.triangle")
							.foregroundStyle(.red)
					}
				}
			}
			.navigationTitle("Send Feedback")
			#if os(iOS)
			.navigationBarTitleDisplayMode(.inline)
			#endif
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") {
						handleDismiss()
					}
				}
				
				ToolbarItem(placement: .confirmationAction) {
					if submissionState == .submitting {
						ProgressView()
					} else {
						Button("Send", systemImage: "checkmark") {
							submit()
						}
						.disabled(!canSubmit)
					}
				}
			}
			.disabled(submissionState == .submitting)
			.overlay {
				if submissionState == .success {
					SuccessOverlay {
						handleDismiss()
					}
				}
			}
			.onAppear {
				focusedField = .message
			}
			.interactiveDismissDisabled(submissionState == .submitting)
		}
	}
	
	private var canSubmit: Bool {
		!message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}
	
	private func submit() {
		guard canSubmit else { return }
		
		submissionState = .submitting
		
		Task {
			do {
				let service = FeedbackService(config: config)
				let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
				let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
				
				_ = try await service.submit(
					type: feedbackType,
					message: trimmedMessage,
					email: trimmedEmail.isEmpty ? nil : trimmedEmail
				)
				
				await MainActor.run {
					submissionState = .success
					
					if !rememberEmail {
						email = ""
					}
				}
			} catch {
				await MainActor.run {
					submissionState = .error(error.localizedDescription)
				}
			}
		}
	}
	
	private func handleDismiss() {
		if let onDismiss {
			onDismiss()
		}
		
		dismiss()
	}
}

// MARK: - Success Overlay

private struct SuccessOverlay: View {
	let onComplete: () -> Void
	
	@State private var checkmarkScale: CGFloat = 0
	
	var body: some View {
		VStack(spacing: 16) {
			Image(systemName: "checkmark.circle.fill")
				.font(.system(size: 64))
				.foregroundStyle(.green)
				.scaleEffect(checkmarkScale)
			
			Text("Thanks for your feedback!")
				.font(.headline)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(.ultraThinMaterial)
		.onAppear {
			withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
				checkmarkScale = 1
			}
			
			DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
				onComplete()
			}
		}
	}
}

// MARK: - View Modifier

/// A view modifier that presents a feedback sheet.
public struct FeedbackSheetModifier: ViewModifier {
	let config: FeedbackConfig
	@Binding var isPresented: Bool
	
	public func body(content: Content) -> some View {
		content.sheet(isPresented: $isPresented) {
			FeedbackView(config: config) {
				isPresented = false
			}
		}
	}
}

public extension View {
	/// Presents a feedback sheet when `isPresented` is true.
	/// - Parameters:
	///   - isPresented: Binding to control sheet presentation
	///   - config: Configuration for the feedback API
	func feedbackSheet(isPresented: Binding<Bool>, config: FeedbackConfig) -> some View {
		modifier(FeedbackSheetModifier(config: config, isPresented: isPresented))
	}
}

// MARK: - Preview

#Preview {
	FeedbackView(
		config: FeedbackConfig(apiKey: "preview", apiBaseURL: "https://example.com")
	)
}
