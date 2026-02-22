import CryptoKit
import Foundation

actor FileHasher {
    static let shared = FileHasher()
    private init() {}

    private let chunkSize = 4 * 1024 * 1024 // 4 MB

    struct CacheEntry: Codable {
        let hash: String
        let modDate: Date
        let fileSize: Int
    }

    private var cache: [String: CacheEntry] = [:]
    private var cacheLoaded = false

    /// Returns the SHA-256 hex string for the first 4 MB of the file at `url`.
    /// Uses a disk-backed cache keyed on (modDate, fileSize) to avoid redundant reads.
    func hash(for url: URL) async -> String? {
        if !cacheLoaded { loadCache() }

        let path = url.path
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let modDate = attrs[.modificationDate] as? Date,
              let fileSize = (attrs[.size] as? NSNumber).map({ Int(truncating: $0) })
        else { return nil }

        // Cache hit (on actor, fast)
        if let entry = cache[path], entry.modDate == modDate, entry.fileSize == fileSize {
            return entry.hash
        }

        // Cache miss: perform I/O outside the actor so concurrent requests can proceed
        let hashString = await Task.detached(priority: .utility) {
            FileHasher.computeHash(url: url, chunkSize: 4 * 1024 * 1024)
        }.value
        guard let hashString else { return nil }

        cache[path] = CacheEntry(hash: hashString, modDate: modDate, fileSize: fileSize)
        return hashString
    }

    /// Clears the in-memory cache and deletes the on-disk cache file.
    func clearCache() {
        cache = [:]
        Task.detached(priority: .background) {
            guard let url = FileHasher.cacheURL() else { return }
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Persists the in-memory cache to disk asynchronously.
    func persistCache() {
        let snapshot = cache
        Task.detached(priority: .background) {
            guard let url = FileHasher.cacheURL() else { return }
            let dir = url.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }

    private func loadCache() {
        cacheLoaded = true
        guard let url = FileHasher.cacheURL(),
              let data = try? Data(contentsOf: url),
              let loaded = try? JSONDecoder().decode([String: CacheEntry].self, from: data)
        else { return }
        cache = loaded
    }

    // nonisolated + static: no actor hop, callable from any thread
    nonisolated static func computeHash(url: URL, chunkSize: Int) -> String? {
        guard let fileHandle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { fileHandle.closeFile() }
        let data = fileHandle.readData(ofLength: chunkSize)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func cacheURL() -> URL? {
        guard let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        return cachesDir
            .appendingPathComponent("com.ninzero.photo-culler")
            .appendingPathComponent("hash_cache.json")
    }
}
