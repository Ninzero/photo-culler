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

    private var isAdvancing = false

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
    ) {
        folderURL = url
        do {
            photos = try PhotoScanner.scan(folderURL: url, rawExtensions: rawExtensions, outputExtensions: outputExtensions)

            // Load persisted ratings
            let savedRatings = RatingStore.load(from: url)
            for (index, photo) in photos.enumerated() {
                if let rating = savedRatings[photo.id] {
                    photos[index].rating = rating
                }
            }

            // Jump to the first unrated photo
            if let firstUnrated = photos.firstIndex(where: { $0.rating == nil }) {
                currentIndex = firstUnrated
            } else {
                currentIndex = 0
            }

            AuditLogger.log("SESSION_START: Loaded folder \(url.lastPathComponent) with \(photos.count) photos, \(savedRatings.count) existing ratings", in: url)
        } catch {
            photos = []
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
        guard !photos.isEmpty, currentIndex >= 0, currentIndex < photos.count else { return }
        guard let folderURL else { return }
        guard !isAdvancing else { return }

        let photo = photos[currentIndex]
        let newRating: Rating? = photos[currentIndex].rating == rating ? nil : rating
        photos[currentIndex].rating = newRating

        // Persist ratings
        var allRatings: [String: Rating] = [:]
        for p in photos where p.rating != nil {
            allRatings[p.id] = p.rating
        }
        RatingStore.save(allRatings, to: folderURL)

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

        // Remove bad photos from in-memory state
        photos.removeAll { $0.rating == .bad }

        // Update persisted ratings (only good photos remain)
        var remainingRatings: [String: Rating] = [:]
        for p in photos where p.rating != nil {
            remainingRatings[p.id] = p.rating
        }
        RatingStore.save(remainingRatings, to: folderURL)

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
