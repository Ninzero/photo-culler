import Foundation

struct PhotoItem: Identifiable {
    let id: String // basename, e.g. "DSC00001"
    var rawURL: URL?
    var outputURL: URL?
    var rating: Rating?
    var fileHash: String? // SHA-256 hex of the primary file (first 4 MB), filled at runtime

    var displayURL: URL? {
        outputURL ?? rawURL
    }
}
