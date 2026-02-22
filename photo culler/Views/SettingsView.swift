import SwiftUI

struct SettingsView: View {
    @Environment(ExtensionSettings.self) private var settings
    @State private var showClearRatingsAlert = false
    @State private var showClearFolderRatingsAlert = false
    @State private var showClearCacheAlert = false

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section("RAW Extensions") {
                ExtensionListEditor(extensions: $settings.rawExtensions)
            }

            Section("Output Extensions") {
                ExtensionListEditor(extensions: $settings.outputExtensions)
            }

            Section {
                Button("Reset to Defaults") {
                    settings.resetToDefaults()
                }
            }

            Section("Data") {
                Button("Clear All Ratings…", role: .destructive) {
                    showClearRatingsAlert = true
                }
                Button("Clear Current Folder Ratings…", role: .destructive) {
                    showClearFolderRatingsAlert = true
                }
                .disabled(RatingStore.shared.currentFolderHashes.isEmpty)
                Button("Clear Hash Cache…", role: .destructive) {
                    showClearCacheAlert = true
                }
            }

            Section {
                Text("Changes will take effect the next time you open a folder.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 600)
        .alert("Clear All Ratings?", isPresented: $showClearRatingsAlert) {
            Button("Clear", role: .destructive) {
                let store = RatingStore.shared
                let good = store.ratings.values.filter { $0 == .good }.count
                let bad  = store.ratings.values.filter { $0 == .bad  }.count
                let total = store.ratings.count
                store.clearAll()
                AuditLogger.log("Cleared all ratings: \(total) total (\(good) good, \(bad) bad)")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all stored ratings across all folders. This action cannot be undone.")
        }
        .alert("Clear Current Folder Ratings?", isPresented: $showClearFolderRatingsAlert) {
            Button("Clear", role: .destructive) {
                let store = RatingStore.shared
                let hashes = store.currentFolderHashes
                let good = hashes.filter { store.ratings[$0] == .good }.count
                let bad  = hashes.filter { store.ratings[$0] == .bad  }.count
                let total = good + bad
                let folderName = store.currentFolderName
                store.clearCurrentFolder()
                AuditLogger.log("Cleared current folder ratings (\(folderName)): \(total) total (\(good) good, \(bad) bad)")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all ratings for photos in the current folder (\(RatingStore.shared.currentFolderName)). This action cannot be undone.")
        }
        .alert("Clear Hash Cache?", isPresented: $showClearCacheAlert) {
            Button("Clear", role: .destructive) {
                Task { await FileHasher.shared.clearCache() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete the thumbnail hash cache. The cache will be rebuilt automatically next time you open a folder.")
        }
    }
}

#Preview {
    SettingsView()
        .environment(ExtensionSettings())
}
