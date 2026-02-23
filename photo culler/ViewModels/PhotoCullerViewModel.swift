import Foundation
import Observation

enum ViewMode {
    case allPhotos
    case rejectedOnly
    case unratedOnly
}

@Observable
class PhotoCullerViewModel {
    var photos: [PhotoItem] = []
    var folderURL: URL?
    var currentIndex: Int = 0
    var showCompletionDialog: Bool = false
    var showDeletionResult: Bool = false
    var deletionResultMessage: String = ""
    var showRenameSheet: Bool = false
    var resultAlertTitle: String = "Deletion Complete"
    var hasJustRenamed: Bool = false

    var isLoadingFolder = false
    private(set) var matchingMode: MatchingMode = .hash

    var viewMode: ViewMode = .allPhotos
    private var filteredViewIndex: Int = 0

    private var isAdvancing = false
    private var isSuspendingRatingsSync = false
    private var ratingsObserver: NSObjectProtocol?

    init() {
        ratingsObserver = NotificationCenter.default.addObserver(
            forName: .ratingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let changed = notification.userInfo?["changedKeys"] as? Set<String> ?? Set<String>()
            self?.syncRatingsFromStore(changedKeys: changed)
        }
    }

    deinit {
        if let obs = ratingsObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    private func syncRatingsFromStore(changedKeys: Set<String>) {
        guard !isSuspendingRatingsSync else { return }
        // clearAll 传空集合时全量同步
        if changedKeys.isEmpty {
            for i in photos.indices {
                photos[i].rating = nil
            }
            return
        }
        for i in photos.indices {
            let photoKeys: Set<String> = matchingMode == .path
                ? [photos[i].pathKey] : Set(photos[i].fileHashes)
            guard photoKeys.contains(where: { changedKeys.contains($0) }) else { continue }
            photos[i].rating = photoKeys.compactMap { RatingStore.shared.ratings[$0] }.first
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

    var badPhotos: [PhotoItem] {
        photos.filter { $0.rating == .bad }
    }

    var unratedPhotos: [PhotoItem] {
        photos.filter { $0.rating == nil }
    }

    var displayedPhotos: [PhotoItem] {
        switch viewMode {
        case .allPhotos:    return photos
        case .rejectedOnly: return badPhotos
        case .unratedOnly:  return unratedPhotos
        }
    }

    var displayedCurrentIndex: Int {
        viewMode == .allPhotos ? currentIndex : filteredViewIndex
    }

    var displayedCurrentPhoto: PhotoItem? {
        switch viewMode {
        case .allPhotos:
            return currentPhoto
        case .rejectedOnly:
            guard filteredViewIndex >= 0, filteredViewIndex < badPhotos.count else { return nil }
            return badPhotos[filteredViewIndex]
        case .unratedOnly:
            guard filteredViewIndex >= 0, filteredViewIndex < unratedPhotos.count else { return nil }
            return unratedPhotos[filteredViewIndex]
        }
    }

    var displayedCanGoNext: Bool {
        viewMode == .allPhotos ? canGoNext : filteredViewIndex < displayedPhotos.count - 1
    }

    var displayedCanGoPrevious: Bool {
        viewMode == .allPhotos ? canGoPrevious : filteredViewIndex > 0
    }

    func loadFolder(
        url: URL,
        rawExtensions: Set<String> = ExtensionSettings.defaultRawExtensions,
        outputExtensions: Set<String> = ExtensionSettings.defaultOutputExtensions,
        matchingMode: MatchingMode = .hash
    ) async {
        self.matchingMode = matchingMode
        isLoadingFolder = true
        folderURL = url
        do {
            let scannedPhotos = try PhotoScanner.scan(folderURL: url, rawExtensions: rawExtensions, outputExtensions: outputExtensions)

            var finalPhotos = scannedPhotos
            if matchingMode == .hash {
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

                for (i, hashes) in hashResults { finalPhotos[i].fileHashes = hashes }
            }
            // 路径模式：fileHashes 保持空 []

            // Apply ratings from shared store
            let store = RatingStore.shared
            for i in finalPhotos.indices {
                let keys: [String] = matchingMode == .path
                    ? [finalPhotos[i].pathKey] : finalPhotos[i].fileHashes
                for key in keys {
                    if let rating = store.ratings[key] { finalPhotos[i].rating = rating; break }
                }
            }
            photos = finalPhotos
            RatingStore.shared.currentFolderKeys = matchingMode == .path
                ? Set(finalPhotos.map { $0.pathKey })
                : Set(finalPhotos.flatMap { $0.fileHashes })
            RatingStore.shared.currentFolderName = url.lastPathComponent

            // Jump to the first unrated photo
            if let firstUnrated = photos.firstIndex(where: { $0.rating == nil }) {
                currentIndex = firstUnrated
            } else {
                currentIndex = 0
            }

            AuditLogger.log("SESSION_START: Loaded \(photos.count) photos, \(store.ratings.count) total global ratings", in: url)
        } catch {
            photos = []
            RatingStore.shared.currentFolderKeys = []
            RatingStore.shared.currentFolderName = ""
        }
        isLoadingFolder = false
    }

    func setViewMode(_ mode: ViewMode) {
        if mode == .allPhotos, let current = displayedCurrentPhoto,
           let idx = photos.firstIndex(where: { $0.id == current.id }) {
            currentIndex = idx
        }
        viewMode = mode
        filteredViewIndex = 0
    }

    func cycleViewMode() {
        switch viewMode {
        case .allPhotos:    setViewMode(.unratedOnly)
        case .unratedOnly:  setViewMode(.rejectedOnly)
        case .rejectedOnly: setViewMode(.allPhotos)
        }
    }

    func enterReviewRejectsMode() {
        setViewMode(.rejectedOnly)
    }

    func exitReviewRejectsMode() {
        setViewMode(.allPhotos)
    }

    func goToDisplayed(index: Int) {
        if viewMode == .allPhotos {
            goTo(index: index)
        } else {
            guard index >= 0, index < displayedPhotos.count else { return }
            filteredViewIndex = index
        }
    }

    func goToNextDisplayed() {
        if viewMode == .allPhotos {
            goToNext()
        } else {
            if filteredViewIndex < displayedPhotos.count - 1 { filteredViewIndex += 1 }
        }
    }

    func goToPreviousDisplayed() {
        if viewMode == .allPhotos {
            goToPrevious()
        } else {
            if filteredViewIndex > 0 { filteredViewIndex -= 1 }
        }
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
        guard let folderURL else { return }
        guard !isAdvancing else { return }

        let photoIdx: Int
        if viewMode != .allPhotos {
            guard filteredViewIndex >= 0, filteredViewIndex < displayedPhotos.count else { return }
            let photoId = displayedPhotos[filteredViewIndex].id
            guard let idx = photos.firstIndex(where: { $0.id == photoId }) else { return }
            photoIdx = idx
        } else {
            guard !photos.isEmpty, currentIndex >= 0, currentIndex < photos.count else { return }
            photoIdx = currentIndex
        }

        let photo = photos[photoIdx]
        let newRating: Rating? = photos[photoIdx].rating == rating ? nil : rating
        photos[photoIdx].rating = newRating

        // Persist rating keyed by path or file hashes via shared store
        let keys: [String] = matchingMode == .path ? [photo.pathKey] : photo.fileHashes
        if !keys.isEmpty {
            RatingStore.shared.applyRating(newRating, forKeys: keys)
        }

        AuditLogger.log("RATED: \(photo.id) -> \(newRating?.rawValue ?? "unrated")", in: folderURL)

        if viewMode != .allPhotos {
            isAdvancing = true
            let shouldShowCompletion = viewMode == .unratedOnly && newRating != nil && allRated
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                isAdvancing = false
                let newCount = self.displayedPhotos.count
                self.filteredViewIndex = min(self.filteredViewIndex, max(0, newCount - 1))
                if shouldShowCompletion {
                    self.showCompletionDialog = true
                }
            }
            return
        }

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

        // Snapshot IDs before modifying RatingStore: applyRating triggers syncRatingsFromStore
        // which may clear ratings synchronously, causing removeAll { $0.rating == .bad } to miss them.
        let badPhotoIds = Set(photos.filter { $0.rating == .bad }.map { $0.id })

        // Remove deleted photos' keys from shared store
        for p in photos where p.rating == .bad {
            let keys: [String] = matchingMode == .path ? [p.pathKey] : p.fileHashes
            RatingStore.shared.applyRating(nil, forKeys: keys)
        }

        // Remove bad photos by ID (immune to rating changes caused by syncRatingsFromStore)
        photos.removeAll { badPhotoIds.contains($0.id) }

        // Exit Rejected Only mode so the user returns to All Photos view
        if viewMode == .rejectedOnly {
            viewMode = .allPhotos
        }

        // Adjust currentIndex to stay in bounds
        if photos.isEmpty {
            currentIndex = 0
        } else if currentIndex >= photos.count {
            currentIndex = photos.count - 1
        }

        resultAlertTitle = "Deletion Complete"
        showDeletionResult = true
    }

    func cancelDeletion() {
        guard let folderURL else { return }
        AuditLogger.log("DELETION_CANCELLED: User cancelled deletion", in: folderURL)
    }

    func performRename(seriesName: String) {
        guard let folderURL, !photos.isEmpty else { return }
        let photosSnapshot = photos
        let currentMode = matchingMode
        let trimmed = seriesName.trimmingCharacters(in: .whitespaces)

        showRenameSheet = false

        Task { @MainActor in
            let result = PhotoRenamer.rename(photos: photosSnapshot, seriesName: trimmed, in: folderURL)

            self.photos = result.renamedPhotos

            if currentMode == .path {
                self.updateRatingStoreAfterRename(
                    oldPhotos: photosSnapshot,
                    newPhotos: result.renamedPhotos
                )
                RatingStore.shared.currentFolderKeys = Set(result.renamedPhotos.map { $0.pathKey })
            }

            self.resultAlertTitle = "Rename Complete"
            self.hasJustRenamed = true
            self.deletionResultMessage = result.summary
            self.showDeletionResult = true
        }
    }

    @MainActor
    private func updateRatingStoreAfterRename(
        oldPhotos: [PhotoItem],
        newPhotos: [PhotoItem]
    ) {
        isSuspendingRatingsSync = true
        for (old, new) in zip(oldPhotos, newPhotos) {
            let oldKey = old.pathKey
            let newKey = new.pathKey
            guard oldKey != newKey else { continue }
            if let rating = RatingStore.shared.ratings[oldKey] {
                RatingStore.shared.applyRating(rating, forKeys: [newKey])
            }
            RatingStore.shared.applyRating(nil, forKeys: [oldKey])
        }
        isSuspendingRatingsSync = false
    }
}
