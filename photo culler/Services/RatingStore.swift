import Foundation
import Observation

extension Notification.Name {
    static let ratingsDidChange = Notification.Name("com.ninzero.photo-culler.ratingsDidChange")
}

@MainActor @Observable final class RatingStore {
    static let shared = RatingStore()

    private(set) var ratings: [String: Rating]
    var currentFolderHashes: Set<String> = []
    var currentFolderName: String = ""

    private init() {
        ratings = RatingStore.loadFromDisk()
    }

    /// 设置或清除评价（nil = 撤销）。更新内存后立即通知其他 ViewModel，并异步写盘。
    func applyRating(_ rating: Rating?, forHashes hashes: [String]) {
        guard !hashes.isEmpty else { return }
        for hash in hashes {
            if let rating {
                ratings[hash] = rating
            } else {
                ratings.removeValue(forKey: hash)
            }
        }
        let changed = Set(hashes)
        NotificationCenter.default.post(
            name: .ratingsDidChange,
            object: nil,
            userInfo: ["changedHashes": changed]
        )
        let snapshot = ratings
        Task.detached {
            RatingStore.saveToDisk(snapshot)
        }
    }

    /// 清除全部评价。
    func clearAll() {
        ratings = [:]
        NotificationCenter.default.post(name: .ratingsDidChange, object: nil, userInfo: ["changedHashes": Set<String>()])
        Task.detached {
            RatingStore.saveToDisk([:])
        }
    }

    /// 清除当前文件夹所有照片的评价。
    func clearCurrentFolder() {
        let hashes = currentFolderHashes
        guard !hashes.isEmpty else { return }
        for hash in hashes { ratings.removeValue(forKey: hash) }
        NotificationCenter.default.post(name: .ratingsDidChange, object: nil, userInfo: ["changedHashes": hashes])
        let snapshot = ratings
        Task.detached {
            RatingStore.saveToDisk(snapshot)
        }
    }

    // MARK: - Private disk helpers

    private nonisolated static func saveToDisk(_ ratings: [String: Rating]) {
        guard let url = ratingsURL() else { return }
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(ratings) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private nonisolated static func loadFromDisk() -> [String: Rating] {
        guard let url = ratingsURL(),
              let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: Rating].self, from: data)
        else { return [:] }
        return dict
    }

    private nonisolated static func ratingsURL() -> URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        return appSupport
            .appendingPathComponent("com.ninzero.photo-culler")
            .appendingPathComponent("ratings.json")
    }
}
