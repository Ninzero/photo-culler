import CryptoKit
import Foundation

struct FileHasher {
    private static let chunkSize = 4 * 1024 * 1024 // 4 MB

    struct CacheEntry: Codable {
        let hash: String
        let modDate: Date
        let fileSize: Int
    }

    private static var cache: [String: CacheEntry] = [:]
    private static var cacheLoaded = false

    /// Returns the SHA-256 hex string for the first 4 MB of the file at `url`.
    /// Uses a disk-backed cache keyed on (modDate, fileSize) to avoid redundant reads.
    static func hash(for url: URL) -> String? {
        if !cacheLoaded { loadCache() }

        let path = url.path
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let modDate = attrs[.modificationDate] as? Date,
              let fileSize = (attrs[.size] as? NSNumber).map({ Int(truncating: $0) })
        else { return nil }

        if let entry = cache[path],
           entry.modDate == modDate,
           entry.fileSize == fileSize {
            return entry.hash
        }

        guard let fileHandle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { fileHandle.closeFile() }

        let data = fileHandle.readData(ofLength: chunkSize)
        let digest = SHA256.hash(data: data)
        let hashString = digest.map { String(format: "%02x", $0) }.joined()

        cache[path] = CacheEntry(hash: hashString, modDate: modDate, fileSize: fileSize)
        return hashString
    }

    /// Persists the in-memory cache to Caches/com.ninzero.photo-culler/hash_cache.json.
    /// Call once after computing hashes for a folder load.
    static func persistCache() {
        guard let url = cacheURL() else { return }
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private static func loadCache() {
        cacheLoaded = true
        guard let url = cacheURL(),
              let data = try? Data(contentsOf: url),
              let loaded = try? JSONDecoder().decode([String: CacheEntry].self, from: data)
        else { return }
        cache = loaded
    }

    private static func cacheURL() -> URL? {
        guard let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        return cachesDir
            .appendingPathComponent("com.ninzero.photo-culler")
            .appendingPathComponent("hash_cache.json")
    }
}
