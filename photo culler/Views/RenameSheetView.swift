import SwiftUI

struct RenameSheetView: View {
    @Bindable var viewModel: PhotoCullerViewModel
    @State private var seriesName: String = ""
    @FocusState private var isTextFieldFocused: Bool

    private var trimmedName: String {
        seriesName.trimmingCharacters(in: .whitespaces)
    }

    private var isValidName: Bool {
        PhotoRenamer.isValidSeriesName(trimmedName)
    }

    private var hasInvalidChars: Bool {
        !seriesName.isEmpty && !isValidName
    }

    private var photoCount: Int { viewModel.photos.count }
    private var digitWidth: Int { max(3, String(photoCount).count) }

    private var previewText: String? {
        guard isValidName, photoCount > 0 else { return nil }
        let first = String(format: "%0\(digitWidth)d", 1)
        let last  = String(format: "%0\(digitWidth)d", photoCount)
        if photoCount == 1 { return "\(trimmedName)-\(first)" }
        return "\(trimmedName)-\(first)  →  \(trimmedName)-\(last)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rename Photos")
                .font(.headline)

            Text("\(photoCount) photo(s) will be renamed.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                TextField("e.g. Wedding-2024", text: $seriesName)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        if isValidName {
                            viewModel.performRename(seriesName: trimmedName)
                        }
                    }

                if hasInvalidChars {
                    Text("Only letters, digits, Chinese characters, hyphens (-), and underscores (_) are allowed.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.1))
                Group {
                    if let preview = previewText {
                        Text(preview)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.primary)
                    } else {
                        Text("Enter a series name to preview")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
            }
            .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("Cancel") {
                    viewModel.showRenameSheet = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Rename") {
                    viewModel.performRename(seriesName: trimmedName)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValidName)
            }
        }
        .padding(20)
        .frame(width: 380)
        .onAppear { isTextFieldFocused = true }
    }
}
