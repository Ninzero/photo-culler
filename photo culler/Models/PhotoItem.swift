import Foundation

struct PhotoItem: Identifiable {
    let id: String // basename, e.g. "DSC00001"
    var rawURL: URL?
    var outputURL: URL?
    var rating: Rating?
    var fileHashes: [String] = [] // SHA-256 hex of each associated file (RAW + output), filled at runtime

    var displayURL: URL? {
        outputURL ?? rawURL
    }

    var pathKey: String {
        (rawURL ?? outputURL)?.deletingPathExtension().path ?? id
    }
}
