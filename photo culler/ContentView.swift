//
//  ContentView.swift
//  photo culler
//
//  Created by Tiansheng Xu on 2026-02-18.
//

import SwiftUI

struct ContentView: View {
    @Environment(PhotoCullerViewModel.self) private var viewModel

    var body: some View {
        Group {
            if viewModel.hasLoadedFolder {
                PhotoReviewView(viewModel: viewModel)
            } else {
                FolderSelectionView { url in
                    viewModel.loadFolder(url: url)
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(PhotoCullerViewModel())
}
