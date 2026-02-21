import SwiftUI
import AppKit

struct FolderSelectionView: View {
    var onFolderSelected: (URL) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Button("Choose Folder...") {
                chooseFolder()
            }
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func chooseFolder() {
        let panel = AppDelegate.openPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder containing photos"

        if panel.runModal() == .OK, let url = panel.url {
            onFolderSelected(url)
        }
    }
}
