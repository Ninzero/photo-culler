import SwiftUI
import AppKit
import ImageIO

// 单个缩略图格子
private struct ThumbnailCell: View {
    let photo: PhotoItem
    let index: Int
    let isSelected: Bool
    let onTap: () -> Void

    @State private var thumbnail: NSImage?
    @State private var isLoading = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Group {
                        if isLoading {
                            Color.clear.overlay(
                                ProgressView().scaleEffect(0.6)
                            )
                        } else if let img = thumbnail {
                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 96, height: 64)
                    .clipped()
                    .background(Color(nsColor: .windowBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                    // 评级角标
                    if let rating = photo.rating {
                        Image(systemName: rating == .good ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(rating == .good ? Color.green : Color.red)
                            .padding(3)
                    }
                }

                Text(photo.id)
                    .font(.system(size: 9))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .task(id: photo.displayURL) {
            guard let url = photo.displayURL else { return }
            isLoading = true
            thumbnail = nil
            let img = await Task.detached(priority: .utility) {
                ThumbnailCell.loadThumbnail(from: url)
            }.value
            thumbnail = img
            isLoading = false
        }
    }

    nonisolated private static func loadThumbnail(from url: URL) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailFromImageAlways: false,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 200
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: .zero)
    }
}

// 右侧缩略图列
struct ThumbnailStripView: View {
    let photos: [PhotoItem]
    let currentIndex: Int
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 2) {
                    ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                        ThumbnailCell(
                            photo: photo,
                            index: index,
                            isSelected: index == currentIndex,
                            onTap: { onSelect(index) }
                        )
                        .id(index)
                    }
                }
                .padding(.vertical, 6)
            }
            .onChange(of: currentIndex) { _, newIndex in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
            .onAppear {
                proxy.scrollTo(currentIndex, anchor: .center)
            }
        }
        .frame(width: 120)
        .background(Color(nsColor: .controlBackgroundColor))
        .shadow(color: .black.opacity(0.18), radius: 8, x: -3, y: 0)
    }
}
