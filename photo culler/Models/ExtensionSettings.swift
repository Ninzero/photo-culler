import Foundation
import Observation

enum MatchingMode: String, CaseIterable {
    case hash = "hash"
    case path = "path"
    var displayName: String {
        switch self {
        case .hash: return "Hash (Recommended)"
        case .path: return "Path (Faster Loading)"
        }
    }
}

@Observable
class ExtensionSettings {
    nonisolated static let defaultRawExtensions: Set<String> = ["3FR", "ARW", "CR2", "CR3", "DNG", "FFF", "NEF", "RAF", "RAW", "RWL"]
    nonisolated static let defaultOutputExtensions: Set<String> = ["JPG", "JPEG", "HIF"]

    private static let rawKey = "rawExtensions"
    private static let outputKey = "outputExtensions"
    private static let matchingModeKey = "matchingMode"

    var rawExtensions: Set<String> {
        didSet { UserDefaults.standard.set(Array(rawExtensions), forKey: Self.rawKey) }
    }

    var outputExtensions: Set<String> {
        didSet { UserDefaults.standard.set(Array(outputExtensions), forKey: Self.outputKey) }
    }

    var matchingMode: MatchingMode {
        didSet { UserDefaults.standard.set(matchingMode.rawValue, forKey: Self.matchingModeKey) }
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

        if let s = UserDefaults.standard.string(forKey: Self.matchingModeKey),
           let m = MatchingMode(rawValue: s) {
            matchingMode = m
        } else {
            matchingMode = .hash
        }
    }

    func resetToDefaults() {
        rawExtensions = Self.defaultRawExtensions
        outputExtensions = Self.defaultOutputExtensions
        matchingMode = .hash
    }
}
