import Foundation
import Observation

@Observable
class ExtensionSettings {
    static let defaultRawExtensions: Set<String> = ["3FR", "ARW", "CR2", "CR3", "DNG", "FFF", "NEF", "RAF", "RAW", "RWL"]
    static let defaultOutputExtensions: Set<String> = ["JPG", "JPEG", "HIF"]

    private static let rawKey = "rawExtensions"
    private static let outputKey = "outputExtensions"

    var rawExtensions: Set<String> {
        didSet { UserDefaults.standard.set(Array(rawExtensions), forKey: Self.rawKey) }
    }

    var outputExtensions: Set<String> {
        didSet { UserDefaults.standard.set(Array(outputExtensions), forKey: Self.outputKey) }
    }

    init() {
        if let saved = UserDefaults.standard.stringArray(forKey: Self.rawKey) {
            rawExtensions = Set(saved)
        } else {
            rawExtensions = Self.defaultRawExtensions
        }

        if let saved = UserDefaults.standard.stringArray(forKey: Self.outputKey) {
            outputExtensions = Set(saved)
        } else {
            outputExtensions = Self.defaultOutputExtensions
        }
    }

    func resetToDefaults() {
        rawExtensions = Self.defaultRawExtensions
        outputExtensions = Self.defaultOutputExtensions
    }
}
