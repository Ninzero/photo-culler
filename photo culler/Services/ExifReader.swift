// photo culler/Services/ExifReader.swift
import Foundation
import ImageIO

actor ExifReader {
    static let shared = ExifReader()
    private init() {}

    // LRU cache: capacity 50, keyed by URL
    private var cache: [URL: ExifData] = [:]
    private var accessOrder: [URL] = []
    private let capacity = 50

    func exif(for url: URL) async -> ExifData? {
        if let cached = cache[url] {
            touch(url)
            return cached
        }
        let task = Task.detached(priority: .utility) { ExifReader.readExif(from: url) }
        guard let result = await task.value else { return nil }
        store(url, result)
        return result
    }

    private func touch(_ url: URL) {
        accessOrder.removeAll { $0 == url }
        accessOrder.append(url)
    }

    private func store(_ url: URL, _ data: ExifData) {
        cache[url] = data
        accessOrder.append(url)
        while accessOrder.count > capacity {
            let evicted = accessOrder.removeFirst()
            cache.removeValue(forKey: evicted)
        }
    }

    // MARK: - Static parsing (nonisolated, runs off-actor)

    nonisolated private static func readExif(from url: URL) -> ExifData? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { return nil }

        let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let gps  = props[kCGImagePropertyGPSDictionary]  as? [CFString: Any]

        var data = ExifData()

        // Exposure
        if let fNumber = exif?[kCGImagePropertyExifFNumber] as? Double {
            data.aperture = String(format: "f/%.1f", fNumber)
        }
        if let et = exif?[kCGImagePropertyExifExposureTime] as? Double, et > 0 {
            if et < 1.0 {
                let denom = Int((1.0 / et).rounded())
                data.shutterSpeed = "1/\(denom)s"
            } else {
                data.shutterSpeed = String(format: "%.1fs", et)
            }
        }
        if let isoList = exif?[kCGImagePropertyExifISOSpeedRatings] as? [Int], let iso = isoList.first {
            data.iso = "ISO \(iso)"
        }
        if let fl = exif?[kCGImagePropertyExifFocalLength] as? Double {
            data.focalLength = String(format: "%.0fmm", fl)
        }
        if let bias = exif?[kCGImagePropertyExifExposureBiasValue] as? Double {
            data.exposureBias = String(format: "%+.1f EV", bias)
        }
        if let prog = exif?[kCGImagePropertyExifExposureProgram] as? Int {
            data.exposureProgram = exposureProgramString(prog)
        }

        // Camera & Lens
        data.make = tiff?[kCGImagePropertyTIFFMake] as? String
        data.model = tiff?[kCGImagePropertyTIFFModel] as? String
        data.lensModel = exif?[kCGImagePropertyExifLensModel] as? String

        // Capture Settings
        if let mm = exif?[kCGImagePropertyExifMeteringMode] as? Int {
            data.meteringMode = meteringModeString(mm)
        }
        if let flashVal = exif?[kCGImagePropertyExifFlash] as? Int {
            data.flash = (flashVal & 0x1) != 0 ? "Fired" : "Did not fire"
        }
        if let wb = exif?[kCGImagePropertyExifWhiteBalance] as? Int {
            data.whiteBalance = wb == 0 ? "Auto" : "Manual"
        }

        // File Info
        data.width  = props[kCGImagePropertyPixelWidth]  as? Int
        data.height = props[kCGImagePropertyPixelHeight] as? Int

        if let profileName = props[kCGImagePropertyProfileName] as? String {
            data.colorProfile = profileName
        } else if let colorModel = props[kCGImagePropertyColorModel] as? String {
            data.colorProfile = colorModel
        }

        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            data.fileSize = size
        }

        if let dateStr = exif?[kCGImagePropertyExifDateTimeOriginal] as? String {
            data.dateTimeOriginal = parseExifDate(dateStr)
        }

        // GPS
        if let lat = gps?[kCGImagePropertyGPSLatitude] as? Double {
            let latRef = gps?[kCGImagePropertyGPSLatitudeRef] as? String
            data.latitude = latRef == "S" ? -lat : lat
        }
        if let lon = gps?[kCGImagePropertyGPSLongitude] as? Double {
            let lonRef = gps?[kCGImagePropertyGPSLongitudeRef] as? String
            data.longitude = lonRef == "W" ? -lon : lon
        }
        if let alt = gps?[kCGImagePropertyGPSAltitude] as? Double {
            let altRef = gps?[kCGImagePropertyGPSAltitudeRef] as? Int
            data.altitude = altRef == 1 ? -alt : alt
        }

        return data
    }

    nonisolated private static func exposureProgramString(_ value: Int) -> String {
        switch value {
        case 0: return "Not defined"
        case 1: return "Manual"
        case 2: return "Normal"
        case 3: return "Aperture Priority"
        case 4: return "Shutter Priority"
        case 5: return "Creative"
        case 6: return "Action"
        case 7: return "Portrait"
        case 8: return "Landscape"
        default: return "Unknown"
        }
    }

    nonisolated private static func meteringModeString(_ value: Int) -> String {
        switch value {
        case 0: return "Unknown"
        case 1: return "Average"
        case 2: return "Center Weighted"
        case 3: return "Spot"
        case 4: return "Multi-spot"
        case 5: return "Multi-segment"
        case 6: return "Partial"
        default: return "Other"
        }
    }

    nonisolated private static func parseExifDate(_ exifDate: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy:MM:dd HH:mm:ss"
        parser.locale = Locale(identifier: "en_US_POSIX")
        guard let date = parser.date(from: exifDate) else { return exifDate }
        let display = DateFormatter()
        display.dateStyle = .medium
        display.timeStyle = .medium
        return display.string(from: date)
    }
}
