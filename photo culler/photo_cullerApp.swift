//
//  photo_cullerApp.swift
//  photo culler
//
//  Created by Tiansheng Xu on 2026-02-18.
//

import SwiftUI
import AppKit

@main
struct photo_cullerApp: App {
    @State private var viewModel = PhotoCullerViewModel()
    @State private var extensionSettings = ExtensionSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
                .environment(extensionSettings)
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open…") {
                    openFolder()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            CommandMenu("Photo") {
                Button("Delete Bad Photos…") {
                    viewModel.showCompletionDialog = true
                }
                .keyboardShortcut("d", modifiers: .command)
                .disabled(!viewModel.hasLoadedFolder || viewModel.badCount == 0)
            }
        }

        Settings {
            SettingsView()
                .environment(extensionSettings)
        }
    }

    private func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder containing photos"

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.loadFolder(
                url: url,
                rawExtensions: extensionSettings.rawExtensions,
                outputExtensions: extensionSettings.outputExtensions
            )
        }
    }
}
