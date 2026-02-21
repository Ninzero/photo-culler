//
//  ContentView.swift
//  photo culler
//
//  Created by Tiansheng Xu on 2026-02-18.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = PhotoCullerViewModel()
    @Environment(ExtensionSettings.self) private var extensionSettings

    var body: some View {
        Group {
            if viewModel.isLoadingFolder {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Loading photos…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.hasLoadedFolder {
                PhotoReviewView(viewModel: viewModel)
            } else {
                FolderSelectionView { url in
                    Task {
                        await viewModel.loadFolder(
                            url: url,
                            rawExtensions: extensionSettings.rawExtensions,
                            outputExtensions: extensionSettings.outputExtensions
                        )
                    }
                }
            }
        }
        .environment(viewModel)
        .focusedSceneValue(\.viewModel, viewModel)
    }
}

#Preview {
    ContentView()
        .environment(PhotoCullerViewModel())
        .environment(ExtensionSettings())
}
