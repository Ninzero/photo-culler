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
                grouped[basename, default: PhotoItem(id: basename)].rawURL = fileURL
            } else if outputExtensions.contains(ext) {
                grouped[basename, default: PhotoItem(id: basename)].outputURL = fileURL
            }
        }

        return grouped.values.sorted { $0.id < $1.id }
    }
}
