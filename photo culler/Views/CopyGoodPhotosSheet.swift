import SwiftUI
import AppKit

struct CopyGoodPhotosSheet: View {
    @Bindable var viewModel: PhotoCullerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.isCopying {
                progressPhase
            } else {
                confirmationPhase
            }
        }
        .padding(20)
        .frame(width: 380)
        .interactiveDismissDisabled(viewModel.isCopying)
    }

    // MARK: - Phase 1: Confirmation

    private var destinationIsSameAsSource: Bool {
        guard let folderURL = viewModel.folderURL else { return false }
        let trimmed = viewModel.copyDestinationPath.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        return URL(fileURLWithPath: trimmed).standardizedFileURL
            == folderURL.standardizedFileURL
    }

    private var isCopyDisabled: Bool {
        viewModel.copyDestinationPath.trimmingCharacters(in: .whitespaces).isEmpty
            || destinationIsSameAsSource
    }

    private var confirmationPhase: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Copy Good Photos")
                .font(.headline)

            Text("Copy \(viewModel.goodCount) good photo(s) to:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                TextField("Destination path", text: $viewModel.copyDestinationPath)
                    .textFieldStyle(.roundedBorder)

                Button("Browse…") {
                    browseDestination()
                }
            }

            if destinationIsSameAsSource {
                Text("Destination cannot be the source folder")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Toggle("Overwrite existing files", isOn: $viewModel.copyOverwrite)

            HStack {
                Spacer()
                Button("Cancel") {
                    viewModel.cancelCopy()
                }
                .keyboardShortcut(.cancelAction)

                Button("Copy") {
                    viewModel.confirmCopy()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isCopyDisabled)
            }
        }
    }

    private func browseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        let currentPath = viewModel.copyDestinationPath.trimmingCharacters(in: .whitespaces)
        if !currentPath.isEmpty {
            let parentURL = URL(fileURLWithPath: currentPath).deletingLastPathComponent()
            panel.directoryURL = parentURL
        }

        panel.begin { response in
            if response == .OK, let url = panel.url {
                viewModel.copyDestinationPath = url.path
            }
        }
    }

    // MARK: - Phase 2: Progress

    private var progressPhase: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Copying…")
                .font(.headline)

            ProgressView(value: viewModel.copyProgress)

            Text(viewModel.copyStatusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
