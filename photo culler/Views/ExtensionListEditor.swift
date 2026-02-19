import SwiftUI

struct ExtensionListEditor: View {
    @Binding var extensions: Set<String>
    @State private var newExtension = ""

    private var sorted: [String] {
        extensions.sorted()
    }

    var body: some View {
        ForEach(sorted, id: \.self) { ext in
            HStack {
                Text(".\(ext)")
                Spacer()
                Button(role: .destructive) {
                    extensions.remove(ext)
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                .disabled(extensions.count <= 1)
            }
        }

        HStack {
            TextField("Extension", text: $newExtension)
                .textFieldStyle(.roundedBorder)
                .onSubmit { addExtension() }
            Button("Add") { addExtension() }
                .disabled(sanitized.isEmpty || extensions.contains(sanitized))
        }
    }

    private var sanitized: String {
        let trimmed = newExtension
            .trimmingCharacters(in: .whitespaces)
            .uppercased()
        let stripped = trimmed.hasPrefix(".") ? String(trimmed.dropFirst()) : trimmed
        let filtered = stripped.filter { $0.isLetter || $0.isNumber }
        return filtered
    }

    private func addExtension() {
        let ext = sanitized
        guard !ext.isEmpty, !extensions.contains(ext) else { return }
        extensions.insert(ext)
        newExtension = ""
    }
}
