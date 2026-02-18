import Foundation

struct PhotoItem: Identifiable {
    let id: String // basename, e.g. "DSC00001"
    var rawURL: URL?
    var outputURL: URL?
    var rating: Rating = .skip

    var displayURL: URL? {
        outputURL ?? rawURL
    }
}
