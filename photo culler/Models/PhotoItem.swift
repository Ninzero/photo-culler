import Foundation

struct PhotoItem: Identifiable {
    let id: String // basename, e.g. "DSC00001"
    var rawURLs: [URL] = [] // each list kept in extension order by PhotoScanner
    var outputURLs: [URL] = []
    var rating: Rating?
    var fileHashes: [String] = [] // SHA-256 hex of each file in fileURLs order, filled at runtime

    /// Every associated file: RAW first, then output. Operations on a photo must go through this.
    nonisolated var fileURLs: [URL] {
        rawURLs + outputURLs
    }

    var displayURL: URL? {
        outputURLs.first ?? rawURLs.first
    }

    var pathKey: String {
        fileURLs.first?.deletingPathExtension().path ?? id
    }
}
