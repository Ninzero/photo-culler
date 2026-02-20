import SwiftUI

struct SettingsView: View {
    @Environment(ExtensionSettings.self) private var settings
    @State private var showClearRatingsAlert = false

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
            }

            Section {
                Text("Changes will take effect the next time you open a folder.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 560)
        .alert("Clear All Ratings?", isPresented: $showClearRatingsAlert) {
            Button("Clear", role: .destructive) {
                let existing = RatingStore.load()
                let good = existing.values.filter { $0 == .good }.count
                let bad  = existing.values.filter { $0 == .bad  }.count
                RatingStore.save([:])
                AuditLogger.log("Cleared all ratings: \(existing.count) total (\(good) good, \(bad) bad)")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all stored ratings across all folders. This action cannot be undone.")
        }
    }
}

#Preview {
    SettingsView()
        .environment(ExtensionSettings())
}
