import Foundation

struct DeletionResult {
    let deletedFiles: [String]
    let failedFiles: [(String, Error)]

    var summary: String {
        var lines: [String] = []
        lines.append("Deleted \(deletedFiles.count) file(s).")
        if !failedFiles.isEmpty {
            lines.append("Failed to delete \(failedFiles.count) file(s):")
            for (path, error) in failedFiles {
                lines.append("  \(path): \(error.localizedDescription)")
            }
        }
        return lines.joined(separator: "\n")
    }
}

struct PhotoDeleter {
    static func deleteBadPhotos(from photos: [PhotoItem], in folderURL: URL) -> DeletionResult {
        let badPhotos = photos.filter { $0.rating == .bad }
        var deletedFiles: [String] = []
        var failedFiles: [(String, Error)] = []
        let fileManager = FileManager.default

        for photo in badPhotos {
            let urls = [photo.rawURL, photo.outputURL].compactMap { $0 }
            for url in urls {
                let fileName = url.lastPathComponent
                do {
                    try fileManager.removeItem(at: url)
                    deletedFiles.append(fileName)
                    AuditLogger.log("DELETED: \(fileName)", in: folderURL)
                } catch {
                    failedFiles.append((fileName, error))
                    AuditLogger.log("DELETE_FAILED: \(fileName) - \(error.localizedDescription)", in: folderURL)
                }
            }
        }

        AuditLogger.log("DELETION_COMPLETE: \(deletedFiles.count) deleted, \(failedFiles.count) failed", in: folderURL)
        return DeletionResult(deletedFiles: deletedFiles, failedFiles: failedFiles)
    }
}
