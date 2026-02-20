import Foundation

struct AuditLogger {
    static func log(_ message: String, in folderURL: URL) {
        guard let url = logURL() else { return }
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let folderName = folderURL.lastPathComponent
        let line = "[\(timestamp)] [\(folderName)] \(message)\n"

        if FileManager.default.fileExists(atPath: url.path) {
            guard let handle = try? FileHandle(forWritingTo: url) else { return }
            handle.seekToEndOfFile()
            if let data = line.data(using: .utf8) {
                handle.write(data)
            }
            handle.closeFile()
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private static func logURL() -> URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        return appSupport
            .appendingPathComponent("com.ninzero.photo-culler")
            .appendingPathComponent("audit.log")
    }
}
