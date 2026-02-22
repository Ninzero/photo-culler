import Foundation
import Observation

@Observable
class PhotoCullerViewModel {
    var photos: [PhotoItem] = []
    var folderURL: URL?
    var currentIndex: Int = 0
    var showCompletionDialog: Bool = false
    var showDeletionResult: Bool = false
    var deletionResultMessage: String = ""

    var isLoadingFolder = false

    private var isAdvancing = false
    private var ratingsObserver: NSObjectProtocol?

    init() {
        ratingsObserver = NotificationCenter.default.addObserver(
            forName: .ratingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let changed = notification.userInfo?["changedHashes"] as? Set<String> ?? Set<String>()
            self?.syncRatingsFromStore(changedHashes: changed)
        }
    }

    deinit {
        if let obs = ratingsObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    private func syncRatingsFromStore(changedHashes: Set<String>) {
        // clearAll 传空集合时全量同步
        if changedHashes.isEmpty {
            for i in photos.indices {
                photos[i].rating = nil
            }
            return
        }
        for i in photos.indices {
            guard photos[i].fileHashes.contains(where: { changedHashes.contains($0) }) else { continue }
            photos[i].rating = photos[i].fileHashes.compactMap { RatingStore.shared.ratings[$0] }.first
        }
    }

    var hasLoadedFolder: Bool {
        folderURL != nil
    }

    var photoCount: Int {
        photos.count
    }

    var currentPhoto: PhotoItem? {
        guard !photos.isEmpty, currentIndex >= 0, currentIndex < photos.count else { return nil }
        return photos[currentIndex]
    }

    var canGoNext: Bool {
        currentIndex < photos.count - 1
    }

    var canGoPrevious: Bool {
        currentIndex > 0
    }

    var ratedCount: Int {
        photos.filter { $0.rating != nil }.count
    }

    var allRated: Bool {
        !photos.isEmpty && ratedCount == photos.count
    }

    var goodCount: Int {
        photos.filter { $0.rating == .good }.count
    }

    var badCount: Int {
        photos.filter { $0.rating == .bad }.count
    }

    func loadFolder(
        url: URL,
        rawExtensions: Set<String> = ExtensionSettings.defaultRawExtensions,
        outputExtensions: Set<String> = ExtensionSettings.defaultOutputExtensions
    ) async {
        isLoadingFolder = true
        folderURL = url
        do {
            let scannedPhotos = try PhotoScanner.scan(folderURL: url, rawExtensions: rawExtensions, outputExtensions: outputExtensions)

            // Compute file hashes concurrently using withTaskGroup (both RAW and output)
            var hashResults = [(Int, [String])](repeating: (0, []), count: scannedPhotos.count)
            await withTaskGroup(of: (Int, [String]).self) { group in
                for i in scannedPhotos.indices {
                    let rawURL = scannedPhotos[i].rawURL
                    let outputURL = scannedPhotos[i].outputURL
                    group.addTask {
                        var hashes: [String] = []
                        if let url = rawURL, let h = await FileHasher.shared.hash(for: url) { hashes.append(h) }
                        if let url = outputURL, let h = await FileHasher.shared.hash(for: url) { hashes.append(h) }
                        return (i, hashes)
                    }
                }
                for await (i, hashes) in group {
                    hashResults[i] = (i, hashes)
                }
            }

            await FileHasher.shared.persistCache()

            var finalPhotos = scannedPhotos
            for (i, hashes) in hashResults { finalPhotos[i].fileHashes = hashes }

            // Apply ratings from shared store by hash (match any file hash)
            let store = RatingStore.shared
            for i in finalPhotos.indices {
                for hash in finalPhotos[i].fileHashes {
                    if let rating = store.ratings[hash] {
                        finalPhotos[i].rating = rating
                        break
                    }
                }
            }
            photos = finalPhotos

            // Jump to the first unrated photo
            if let firstUnrated = photos.firstIndex(where: { $0.rating == nil }) {
                currentIndex = firstUnrated
            } else {
                currentIndex = 0
            }

            AuditLogger.log("SESSION_START: Loaded \(photos.count) photos, \(store.ratings.count) total global ratings", in: url)
        } catch {
            photos = []
        }
        isLoadingFolder = false
    }

    func goToNext() {
        if canGoNext {
            currentIndex += 1
        }
    }

    func goToPrevious() {
        if canGoPrevious {
            currentIndex -= 1
        }
    }

    func goTo(index: Int) {
        guard index >= 0, index < photos.count else { return }
        currentIndex = index
    }

    func rateCurrent(_ rating: Rating) {
        guard !photos.isEmpty, currentIndex >= 0, currentIndex < photos.count else { return }
        guard let folderURL else { return }
        guard !isAdvancing else { return }

        let photo = photos[currentIndex]
        let newRating: Rating? = photos[currentIndex].rating == rating ? nil : rating
        photos[currentIndex].rating = newRating

        // Persist rating keyed by all file hashes via shared store
        if !photo.fileHashes.isEmpty {
            RatingStore.shared.applyRating(newRating, forHashes: photo.fileHashes)
        }

        AuditLogger.log("RATED: \(photo.id) -> \(newRating?.rawValue ?? "unrated")", in: folderURL)

        guard newRating != nil else { return }   // 撤销评价时不自动跳转

        let shouldShowCompletion = allRated
        let shouldAdvance = !allRated && canGoNext

        isAdvancing = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            isAdvancing = false
            if shouldShowCompletion {
                showCompletionDialog = true
            } else if shouldAdvance {
                goToNext()
            }
        }
    }

    func confirmDeletion() {
        guard let folderURL else { return }

        AuditLogger.log("DELETION_CONFIRMED: User confirmed deletion of \(badCount) bad photo(s)", in: folderURL)

        let result = PhotoDeleter.deleteBadPhotos(from: photos, in: folderURL)
        deletionResultMessage = result.summary

        // Remove deleted photos' hashes from shared store
        for p in photos where p.rating == .bad {
            RatingStore.shared.applyRating(nil, forHashes: p.fileHashes)
        }

        // Remove bad photos from in-memory state
        photos.removeAll { $0.rating == .bad }

        // Adjust currentIndex to stay in bounds
        if photos.isEmpty {
            currentIndex = 0
        } else if currentIndex >= photos.count {
            currentIndex = photos.count - 1
        }

        showDeletionResult = true
    }

    func cancelDeletion() {
        guard let folderURL else { return }
        AuditLogger.log("DELETION_CANCELLED: User cancelled deletion", in: folderURL)
    }
}
