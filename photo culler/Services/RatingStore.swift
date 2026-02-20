import Foundation

struct RatingStore {
    static func load() -> [String: Rating] {
        guard let url = ratingsURL(),
              let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: Rating].self, from: data)
        else { return [:] }
        return dict
    }

    static func save(_ ratings: [String: Rating]) {
        guard let url = ratingsURL() else { return }
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(ratings) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private static func ratingsURL() -> URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        return appSupport
            .appendingPathComponent("com.ninzero.photo-culler")
            .appendingPathComponent("ratings.json")
    }
}
