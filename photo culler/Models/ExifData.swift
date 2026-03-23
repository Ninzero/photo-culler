// photo culler/Models/ExifData.swift
import Foundation

struct ExifData {
    // Exposure
    var aperture: String?         // "f/2.8"
    var shutterSpeed: String?     // "1/500s"
    var iso: String?              // "ISO 1600"
    var focalLength: String?      // "85mm"
    var exposureBias: String?     // "+0.3 EV"
    var exposureProgram: String?  // "Aperture Priority"

    // Camera & Lens
    var make: String?             // "SONY"
    var model: String?            // "ILCE-7M3"
    var lensModel: String?        // "FE 85mm F1.4 GM"

    // Capture Settings
    var meteringMode: String?     // "Multi-segment"
    var flash: String?            // "Did not fire"
    var whiteBalance: String?     // "Auto"

    // File Info
    var width: Int?
    var height: Int?
    var colorProfile: String?     // "sRGB IEC61966-2.1" / "Display P3"
    var fileSize: Int64?          // bytes
    var dateTimeOriginal: String? // formatted locale date+time

    // GPS
    var latitude: Double?
    var longitude: Double?
    var altitude: Double?         // meters

    var coordinateString: String? {
        guard let lat = latitude, let lon = longitude else { return nil }
        let latRef = lat >= 0 ? "N" : "S"
        let lonRef = lon >= 0 ? "E" : "W"
        return String(format: "%.4f° %@, %.4f° %@", abs(lat), latRef, abs(lon), lonRef)
    }

    var altitudeString: String? {
        guard let alt = altitude else { return nil }
        return String(format: "%.1f m", alt)
    }
}
