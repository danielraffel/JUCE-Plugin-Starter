import SwiftUI

struct MainView: View {
    @StateObject private var viewModel: DiagnosticViewModel
    @State private var userFeedback = ""

    init(config: AppConfig) {
        _viewModel = StateObject(wrappedValue: DiagnosticViewModel(config: config))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Content based on state
            Group {
                switch viewModel.state {
                case .idle:
                    idleView
                case .collecting:
                    collectingView
                case .submitting:
                    submittingView
                case .success(let url):
                    successView(url: url)
                case .error(let message):
                    errorView(message: message)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: CGFloat(viewModel.config.windowWidth),
               height: CGFloat(viewModel.config.windowHeight))
    }

    private var headerView: some View {
        VStack(spacing: 8) {
            Text(viewModel.config.appName)
                .font(.title2)
                .fontWeight(.semibold)

            Text("Submit a diagnostic report to help us troubleshoot issues")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var idleView: some View {
        VStack(spacing: 20) {
            Image(systemName: "stethoscope")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
                .padding(.bottom, 10)

            if viewModel.config.showPrivacyNotice {
                privacyNotice
            }

            if viewModel.config.allowUserFeedback {
                feedbackSection
            }

            Spacer()

            Button(action: {
                Task {
                    await viewModel.collectAndSubmit(userFeedback: userFeedback)
                }
            }) {
                Label("Collect & Submit Diagnostic", systemImage: "paperplane.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }

    private var privacyNotice: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Label("Privacy Notice", systemImage: "lock.shield")
                    .font(.headline)

                Text("This diagnostic report will include:")
                    .font(.subheadline)

                VStack(alignment: .leading, spacing: 4) {
                    bulletPoint("System information (macOS version, hardware)")
                    bulletPoint("Plugin installation status")
                    bulletPoint("Recent crash logs (if any)")
                    bulletPoint("Audio Unit validation results")
                }
                .font(.caption)

                Text("No personal data is collected beyond what's needed for support.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
    }

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Describe the issue (optional):")
                .font(.subheadline)
                .fontWeight(.medium)

            TextEditor(text: $userFeedback)
                .frame(height: 80)
                .padding(4)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
    }

    private var collectingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()

            Text("Collecting diagnostic information...")
                .font(.headline)

            Text(viewModel.statusMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var submittingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()

            Text("Submitting to GitHub...")
                .font(.headline)

            Text("Creating issue in \(viewModel.config.githubRepo)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func successView(url: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("Report Submitted Successfully!")
                .font(.headline)

            Text("Your diagnostic report has been created.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Issue URL:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(url)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }

            Spacer()

            HStack {
                Button("Open in Browser") {
                    if let issueURL = URL(string: url) {
                        NSWorkspace.shared.open(issueURL)
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Done") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Submission Failed")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if !viewModel.config.supportEmail.isEmpty {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Alternative: Email Support")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        HStack {
                            Text(viewModel.config.supportEmail)
                                .font(.caption)
                                .textSelection(.enabled)

                            Button("Copy") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(viewModel.config.supportEmail, forType: .string)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }

            Spacer()

            HStack {
                Button("Try Again") {
                    viewModel.reset()
                }
                .buttonStyle(.borderedProminent)

                Button("Cancel") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
            Text(text)
            Spacer()
        }
    }
}

// MARK: - View Model

@MainActor
class DiagnosticViewModel: ObservableObject {
    enum State {
        case idle
        case collecting
        case submitting
        case success(String)
        case error(String)
    }

    @Published var state: State = .idle
    @Published var statusMessage = ""

    let config: AppConfig
    private let collector: DiagnosticCollector
    private let uploader: GitHubUploader

    init(config: AppConfig) {
        self.config = config
        self.collector = DiagnosticCollector(config: config)
        self.uploader = GitHubUploader(config: config)
    }

    func collectAndSubmit(userFeedback: String) async {
        // Collect phase
        state = .collecting
        statusMessage = "Gathering system information..."

        do {
            let diagnosticData = await collector.collectDiagnostics(userFeedback: userFeedback)

            // Submit phase
            state = .submitting
            statusMessage = "Creating GitHub issue..."

            let issueURL = try await uploader.submitDiagnostic(diagnosticData)

            // Success
            state = .success(issueURL)

        } catch GitHubError.invalidConfiguration {
            state = .error("GitHub configuration is invalid. Please check your .env file.")
        } catch GitHubError.authenticationError {
            state = .error("GitHub authentication failed. Please check your Personal Access Token.")
        } catch GitHubError.rateLimitExceeded {
            state = .error("GitHub rate limit exceeded. Please try again later.")
        } catch {
            state = .error("Failed to submit report: \(error.localizedDescription)")
        }
    }

    func reset() {
        state = .idle
        statusMessage = ""
    }
}
