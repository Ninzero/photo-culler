import SwiftUI

struct CopyGoodPhotosSheet: View {
    @Bindable var viewModel: PhotoCullerViewModel

    private var folderName: String {
        viewModel.folderURL?.lastPathComponent ?? ""
    }

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

    private var confirmationPhase: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Copy Good Photos")
                .font(.headline)

            Text("Copy \(viewModel.goodCount) good photo(s) to:\n\(folderName)/Prized")
                .font(.subheadline)
                .foregroundStyle(.secondary)

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
