import SwiftUI
import AppKit

struct PhotoDisplayView: View {
    let url: URL?

    var body: some View {
        Group {
            if let url, let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
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
    }
}
