import Foundation

struct RatingStore {
    private static let fileName = ".photo_culler_ratings.json"

    static func fileURL(in folderURL: URL) -> URL {
        folderURL.appendingPathComponent(fileName)
    }

    static func load(from folderURL: URL) -> [String: Rating] {
        let url = fileURL(in: folderURL)
        guard let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: Rating].self, from: data) else {
            return [:]
        }
        return dict
    }

    static func save(_ ratings: [String: Rating], to folderURL: URL) {
        let url = fileURL(in: folderURL)
        guard let data = try? JSONEncoder().encode(ratings) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
