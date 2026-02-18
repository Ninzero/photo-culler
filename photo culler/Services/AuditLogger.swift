import Foundation

struct AuditLogger {
    private static let fileName = ".photo_culler_audit.log"

    static func log(_ message: String, in folderURL: URL) {
        let url = folderURL.appendingPathComponent(fileName)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"

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
}
