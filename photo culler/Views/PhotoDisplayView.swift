import SwiftUI
import AppKit

struct PhotoDisplayView: View {
    let url: URL?

    @State private var loadedImage: NSImage?
    @State private var isLoading = false

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading...")
                        .foregroundStyle(.secondary)
                }
            } else if let image = loadedImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                ContentUnavailableView(
                    "No Image",
                    systemImage: "photo",
                    description: Text("Unable to load image")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: url) {
            guard let url else {
                loadedImage = nil
                isLoading = false
                return
            }
            isLoading = true
            loadedImage = nil
            let image = await Task.detached(priority: .userInitiated) {
                NSImage(contentsOf: url)
            }.value
            loadedImage = image
            isLoading = false
        }
    }
}
