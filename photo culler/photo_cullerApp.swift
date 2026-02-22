//
//  photo_cullerApp.swift
//  photo culler
//
//  Created by Tiansheng Xu on 2026-02-18.
//

import SwiftUI
import AppKit

private struct ViewModelFocusedKey: FocusedValueKey {
    typealias Value = PhotoCullerViewModel
}

extension FocusedValues {
    var viewModel: PhotoCullerViewModel? {
        get { self[ViewModelFocusedKey.self] }
        set { self[ViewModelFocusedKey.self] = newValue }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private static var cachedPanel: NSOpenPanel?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Pre-warm NSOpenPanel on next run loop iteration to avoid blocking window display
        DispatchQueue.main.async {
            Self.cachedPanel = NSOpenPanel()
        }
    }

    static func openPanel() -> NSOpenPanel {
        if let panel = cachedPanel {
            return panel
        }
        let panel = NSOpenPanel()
        cachedPanel = panel
        return panel
    }
}

@main
struct photo_cullerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var extensionSettings = ExtensionSettings()
    @FocusedValue(\.viewModel) private var viewModel

    var body: some Scene {
        WindowGroup {
            ContentView()
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
                    viewModel?.showCompletionDialog = true
                }
                .keyboardShortcut("d", modifiers: .command)
                .disabled(!(viewModel?.hasLoadedFolder ?? false) || (viewModel?.badCount ?? 0) == 0)
            }
            CommandMenu("View") {
                Button("Normal") {
                    viewModel?.exitReviewRejectsMode()
                }
                .disabled(!(viewModel?.hasLoadedFolder ?? false) || !(viewModel?.isReviewRejectsMode ?? false))

                Button("Review Rejects") {
                    viewModel?.enterReviewRejectsMode()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(!(viewModel?.hasLoadedFolder ?? false) || (viewModel?.isReviewRejectsMode ?? false))
            }
        }

        Settings {
            SettingsView()
                .environment(extensionSettings)
        }
    }

    private func openFolder() {
        let panel = AppDelegate.openPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder containing photos"

        if panel.runModal() == .OK, let url = panel.url {
            Task { @MainActor in
                await viewModel?.loadFolder(
                    url: url,
                    rawExtensions: extensionSettings.rawExtensions,
                    outputExtensions: extensionSettings.outputExtensions,
                    matchingMode: extensionSettings.matchingMode
                )
            }
        }
    }
}
