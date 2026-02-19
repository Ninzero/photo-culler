import SwiftUI

struct SettingsView: View {
    @Environment(ExtensionSettings.self) private var settings

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

            Section {
                Text("Changes will take effect the next time you open a folder.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 500)
    }
}

#Preview {
    SettingsView()
        .environment(ExtensionSettings())
}
