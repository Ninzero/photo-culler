import Foundation

struct CopyResult {
    let copiedFiles: [String]
    let skippedFiles: [String]
    let failedFiles: [(String, Error)]

    var summary: String {
        var lines: [String] = []
        lines.append("Copied \(copiedFiles.count) file(s).")
        if !skippedFiles.isEmpty {
            lines.append("Skipped \(skippedFiles.count) file(s) (already exist).")
        }
        if !failedFiles.isEmpty {
            lines.append("Failed to copy \(failedFiles.count) file(s):")
            for (name, error) in failedFiles {
                lines.append("  \(name): \(error.localizedDescription)")
            }
        }
        return lines.joined(separator: "\n")
    }
}

struct PhotoCopier {
    static func copyGoodPhotos(
        from photos: [PhotoItem],
        to destinationURL: URL,
        in folderURL: URL,
        overwrite: Bool,
        onProgress: @Sendable (Int, Int) -> Void
    ) -> CopyResult {
        let goodPhotos = photos.filter { $0.rating == .good }
        let allURLs: [(URL, String)] = goodPhotos.flatMap { photo in
            [photo.rawURL, photo.outputURL].compactMap { $0 }.map { ($0, $0.lastPathComponent) }
        }
        let totalFiles = allURLs.count

        var copiedFiles: [String] = []
        var skippedFiles: [String] = []
        var failedFiles: [(String, Error)] = []
        let fileManager = FileManager.default

        // Create destination directory if needed
        do {
            try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        } catch {
            // All files fail if directory creation fails
            for (_, fileName) in allURLs {
                failedFiles.append((fileName, error))
                AuditLogger.log("COPY_FAILED: \(fileName) - \(error.localizedDescription)", in: folderURL)
            }
            AuditLogger.log("COPY_COMPLETE: 0 copied, 0 skipped, \(failedFiles.count) failed", in: folderURL)
            onProgress(totalFiles, totalFiles)
            return CopyResult(copiedFiles: copiedFiles, skippedFiles: skippedFiles, failedFiles: failedFiles)
        }

        var completed = 0
        for (sourceURL, fileName) in allURLs {
            let destURL = destinationURL.appendingPathComponent(fileName)
            let destExists = fileManager.fileExists(atPath: destURL.path)

            if destExists && !overwrite {
                skippedFiles.append(fileName)
                AuditLogger.log("COPY_SKIPPED: \(fileName)", in: folderURL)
            } else if destExists && overwrite {
                // Atomic overwrite: copy to temp, then replaceItemAt
                let tmpURL = destinationURL.appendingPathComponent(UUID().uuidString + ".tmp")
                do {
                    try fileManager.copyItem(at: sourceURL, to: tmpURL)
                    _ = try fileManager.replaceItemAt(destURL, withItemAt: tmpURL)
                    copiedFiles.append(fileName)
                    AuditLogger.log("COPIED: \(fileName)", in: folderURL)
                } catch {
                    // Clean up temp file if it exists
                    try? fileManager.removeItem(at: tmpURL)
                    failedFiles.append((fileName, error))
                    AuditLogger.log("COPY_FAILED: \(fileName) - \(error.localizedDescription)", in: folderURL)
                }
            } else {
                // Destination does not exist — standard copy
                do {
                    try fileManager.copyItem(at: sourceURL, to: destURL)
                    copiedFiles.append(fileName)
                    AuditLogger.log("COPIED: \(fileName)", in: folderURL)
                } catch {
                    failedFiles.append((fileName, error))
                    AuditLogger.log("COPY_FAILED: \(fileName) - \(error.localizedDescription)", in: folderURL)
                }
            }

            completed += 1
            onProgress(completed, totalFiles)
        }

        AuditLogger.log("COPY_COMPLETE: \(copiedFiles.count) copied, \(skippedFiles.count) skipped, \(failedFiles.count) failed", in: folderURL)
        return CopyResult(copiedFiles: copiedFiles, skippedFiles: skippedFiles, failedFiles: failedFiles)
    }
}
