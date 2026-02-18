import SwiftUI
import AppKit
import ImageIO

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
                Self.loadImage(from: url)
            }.value
            loadedImage = image
            isLoading = false
        }
    }

    // 使用 ImageIO 加载图片，对 RAW 文件直接读取内嵌 JPEG 预览，避免主线程阻塞
    private static func loadImage(from url: URL) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailFromImageAlways: false,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 4096
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: .zero)
    }
}
