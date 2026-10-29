import Foundation

struct PhotoScanner {
    static func scan(
        folderURL: URL,
        rawExtensions: Set<String> = ExtensionSettings.defaultRawExtensions,
        outputExtensions: Set<String> = ExtensionSettings.defaultOutputExtensions
    ) throws -> [PhotoItem] {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        var grouped: [String: PhotoItem] = [:]

        for fileURL in contents {
            let ext = fileURL.pathExtension.uppercased()
            let basename = fileURL.deletingPathExtension().lastPathComponent

            if rawExtensions.contains(ext) {
                grouped[basename, default: PhotoItem(id: basename)].rawURLs.append(fileURL)
            } else if outputExtensions.contains(ext) {
                grouped[basename, default: PhotoItem(id: basename)].outputURLs.append(fileURL)
            }
        }

        // Finder-style natural order; ties fall back to code-point order so the result
        // never depends on dictionary iteration order.
        return grouped.values
            .map { photo in
                var photo = photo
                photo.rawURLs.sort(by: extensionOrder)
                photo.outputURLs.sort(by: extensionOrder)
                return photo
            }
            .sorted {
                let order = $0.id.localizedStandardCompare($1.id)
                return order == .orderedSame ? $0.id < $1.id : order == .orderedAscending
            }
    }

    // Case-insensitive extension order; ties (e.g. ".JPG" and ".jpg" on a case-sensitive volume)
    // fall back to code-point order so the result never depends on directory listing order.
    nonisolated private static func extensionOrder(_ a: URL, _ b: URL) -> Bool {
        let order = a.pathExtension.caseInsensitiveCompare(b.pathExtension)
        return order == .orderedSame ? a.lastPathComponent < b.lastPathComponent : order == .orderedAscending
    }
}
