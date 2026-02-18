//
//  ContentView.swift
//  photo culler
//
//  Created by Tiansheng Xu on 2026-02-18.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = PhotoCullerViewModel()

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
}
