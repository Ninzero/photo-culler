//
//  photo_cullerApp.swift
//  photo culler
//
//  Created by Tiansheng Xu on 2026-02-18.
//

import SwiftUI

@main
struct photo_cullerApp: App {
    @State private var viewModel = PhotoCullerViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandMenu("Photo") {
                Button("Delete Bad Photos…") {
                    viewModel.showCompletionDialog = true
                }
                .keyboardShortcut("d", modifiers: .command)
                .disabled(!viewModel.hasLoadedFolder || viewModel.badCount == 0)
            }
        }
    }
}
