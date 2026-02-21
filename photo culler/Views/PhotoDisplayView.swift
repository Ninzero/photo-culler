import SwiftUI
import AppKit
import ImageIO

struct PhotoDisplayView: View {
    let url: URL?

    @State private var loadedImage: NSImage?
    @State private var isLoading = false
    @State private var scale: CGFloat = 1.0
    @State private var dragOffset: CGSize = .zero

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
                zoomableImage(image)
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
            resetZoom()
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

    @ViewBuilder
    private func zoomableImage(_ image: NSImage) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .offset(dragOffset)
                .overlay(
                    // 用 AppKit 原生事件统一处理捏合/滚轮/拖拽/双击，
                    // 避免 NSView overlay 干扰 SwiftUI MagnificationGesture
                    InteractionOverlay(
                        onZoom: { factor, cursor, viewSize in
                            let newScale = max(1.0, min(20.0, scale * factor))
                            let ratio = newScale / scale
                            // 将光标从 AppKit 坐标转换到 SwiftUI 坐标系（Y 轴翻转）
                            let dx = cursor.x - viewSize.width / 2
                            let dy = viewSize.height / 2 - cursor.y
                            dragOffset = CGSize(
                                width:  ratio * dragOffset.width  + (1 - ratio) * dx,
                                height: ratio * dragOffset.height + (1 - ratio) * dy
                            )
                            scale = newScale
                            if scale <= 1.0 { scale = 1.0; dragOffset = .zero }
                        },
                        onPanDelta: { delta in
                            guard scale > 1.05 else { return }
                            dragOffset.width += delta.width
                            dragOffset.height += delta.height
                        },
                        onDoubleTap: { location, viewSize in
                            // scale == 1 时放大到点击位置；已缩放时重置
                            if scale > 1.05 {
                                withAnimation(.spring(duration: 0.25)) { resetZoom() }
                            } else {
                                let targetScale: CGFloat = 2.5
                                let cx = viewSize.width / 2
                                let cy = viewSize.height / 2
                                // AppKit Y 轴向上，偏移 X 同向，Y 需翻转
                                let newOffset = CGSize(
                                    width: (targetScale - 1) * (cx - location.x),
                                    height: (targetScale - 1) * (location.y - cy)
                                )
                                withAnimation(.spring(duration: 0.25)) {
                                    scale = targetScale
                                    dragOffset = newOffset
                                }
                            }
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                )

            if scale > 1.05 {
                Text("\(Int((scale * 100).rounded()))%")
                    .font(.caption2)
                    .monospacedDigit()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
                    .padding(8)
            }
        }
    }

    private func resetZoom() {
        scale = 1.0
        dragOffset = .zero
    }

    // 使用 ImageIO 加载图片，对 RAW 文件直接读取内嵌 JPEG 预览，避免主线程阻塞
    private nonisolated static func loadImage(from url: URL) -> NSImage? {
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

// 用 AppKit 原生事件捕捉所有交互，避免 SwiftUI 手势识别层的干扰
private struct InteractionOverlay: NSViewRepresentable {
    let onZoom: (_ factor: CGFloat, _ cursorAppKit: CGPoint, _ viewSize: CGSize) -> Void
    let onPanDelta: (CGSize) -> Void
    let onDoubleTap: (_ location: CGPoint, _ viewSize: CGSize) -> Void

    func makeNSView(context: Context) -> InteractionView {
        InteractionView(onZoom: onZoom, onPanDelta: onPanDelta, onDoubleTap: onDoubleTap)
    }

    func updateNSView(_ nsView: InteractionView, context: Context) {
        nsView.onZoom = onZoom
        nsView.onPanDelta = onPanDelta
        nsView.onDoubleTap = onDoubleTap
    }

    final class InteractionView: NSView {
        var onZoom: (_ factor: CGFloat, _ cursorAppKit: CGPoint, _ viewSize: CGSize) -> Void
        var onPanDelta: (CGSize) -> Void
        var onDoubleTap: (_ location: CGPoint, _ viewSize: CGSize) -> Void

        private var lastDragLocation: CGPoint = .zero

        init(
            onZoom: @escaping (_ factor: CGFloat, _ cursorAppKit: CGPoint, _ viewSize: CGSize) -> Void,
            onPanDelta: @escaping (CGSize) -> Void,
            onDoubleTap: @escaping (_ location: CGPoint, _ viewSize: CGSize) -> Void
        ) {
            self.onZoom = onZoom
            self.onPanDelta = onPanDelta
            self.onDoubleTap = onDoubleTap
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { fatalError() }

        private func viewSize() -> CGSize { CGSize(width: bounds.width, height: bounds.height) }

        // 鼠标滚轮缩放
        override func scrollWheel(with event: NSEvent) {
            let delta = event.scrollingDeltaY
            guard abs(delta) > 0.001 else {
                super.scrollWheel(with: event)
                return
            }
            let clamped = max(-20.0, min(20.0, -delta))
            let cursor = convert(event.locationInWindow, from: nil)
            onZoom(1.0 + clamped * 0.01, cursor, viewSize())
        }

        // 触控板双指捏合缩放（AppKit magnify 事件，每帧给出增量）
        override func magnify(with event: NSEvent) {
            let factor = 1.0 + event.magnification
            guard factor > 0 else { return }
            let cursor = convert(event.locationInWindow, from: nil)
            onZoom(factor, cursor, viewSize())
        }

        // 拖拽平移
        override func mouseDown(with event: NSEvent) {
            if event.clickCount == 2 {
                let location = convert(event.locationInWindow, from: nil)
                onDoubleTap(location, CGSize(width: bounds.width, height: bounds.height))
            } else {
                lastDragLocation = convert(event.locationInWindow, from: nil)
            }
        }

        override func mouseDragged(with event: NSEvent) {
            let location = convert(event.locationInWindow, from: nil)
            // AppKit Y 轴向上，SwiftUI Y 轴向下，需要翻转
            let delta = CGSize(
                width: location.x - lastDragLocation.x,
                height: -(location.y - lastDragLocation.y)
            )
            lastDragLocation = location
            onPanDelta(delta)
        }
    }
}
