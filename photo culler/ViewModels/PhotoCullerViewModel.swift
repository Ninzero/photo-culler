import Foundation
import Observation

@Observable
class PhotoCullerViewModel {
    var photos: [PhotoItem] = []
    var folderURL: URL?

    var hasLoadedFolder: Bool {
        folderURL != nil
    }

    var photoCount: Int {
        photos.count
    }

    func loadFolder(url: URL) {
        folderURL = url
        do {
            photos = try PhotoScanner.scan(folderURL: url)
        } catch {
            photos = []
        }
    }
}
