import Foundation

struct PhotoScanner {
    private static let rawExtensions: Set<String> = ["arw", "dng", "raw"]
    private static let outputExtensions: Set<String> = ["jpg", "jpeg", "hif"]

    static func scan(folderURL: URL) throws -> [PhotoItem] {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        var grouped: [String: PhotoItem] = [:]

        for fileURL in contents {
            let ext = fileURL.pathExtension.lowercased()
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
