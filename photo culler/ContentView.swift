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
    @Environment(\.controlActiveState) private var controlActiveState

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
        .onChange(of: controlActiveState) { _, newValue in
            guard newValue == .key else { return }
            if viewModel.photos.isEmpty {
                RatingStore.shared.currentFolderHashes = []
                RatingStore.shared.currentFolderName = ""
            } else {
                RatingStore.shared.currentFolderHashes = Set(viewModel.photos.flatMap { $0.fileHashes })
                RatingStore.shared.currentFolderName = viewModel.folderURL?.lastPathComponent ?? ""
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(PhotoCullerViewModel())
        .environment(ExtensionSettings())
}
