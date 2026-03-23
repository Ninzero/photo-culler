// photo culler/Views/ExifPanelView.swift
import SwiftUI

struct ExifPanelView: View {
    let isLoading: Bool
    let exif: ExifData?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let exif {
                exifContent(exif)
            } else {
                Text("No EXIF data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 240)
        .background(Color(nsColor: .controlBackgroundColor))
        .shadow(color: .black.opacity(0.18), radius: 8, x: 3, y: 0)
    }

    @ViewBuilder
    private func exifContent(_ exif: ExifData) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Exposure
                let exposureRows: [(String, String?)] = [
                    ("Aperture",   exif.aperture),
                    ("Shutter",    exif.shutterSpeed),
                    ("ISO",        exif.iso),
                    ("Focal",      exif.focalLength),
                    ("Exp. Bias",  exif.exposureBias),
                    ("Program",    exif.exposureProgram),
                ]
                section("Exposure", rows: exposureRows)

                // Camera & Lens
                let cameraRows: [(String, String?)] = [
                    ("Make",  exif.make),
                    ("Model", exif.model),
                    ("Lens",  exif.lensModel),
                ]
                section("Camera & Lens", rows: cameraRows)

                // Capture Settings
                let captureRows: [(String, String?)] = [
                    ("Metering",       exif.meteringMode),
                    ("Flash",          exif.flash),
                    ("White Balance",  exif.whiteBalance),
                ]
                section("Capture Settings", rows: captureRows)

                // File Info
                let fileRows: [(String, String?)] = [
                    ("Dimensions",  dimensionsString(exif)),
                    ("Color",       exif.colorProfile),
                    ("File Size",   fileSizeString(exif.fileSize)),
                    ("Date",        exif.dateTimeOriginal),
                    ("Location",    exif.coordinateString),
                    ("Altitude",    exif.altitudeString),
                ]
                section("File Info", rows: fileRows)
            }
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func section(_ title: String, rows: [(String, String?)]) -> some View {
        let present = rows.filter { $0.1 != nil }
        if !present.isEmpty {
            Text(title.uppercased())
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 4)

            ForEach(present, id: \.0) { label, value in
                HStack(alignment: .top, spacing: 8) {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(value ?? "")
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 3)
            }
        }
    }

    private func dimensionsString(_ exif: ExifData) -> String? {
        guard let w = exif.width, let h = exif.height else { return nil }
        return "\(w) x \(h)"
    }

    private func fileSizeString(_ bytes: Int64?) -> String? {
        guard let bytes else { return nil }
        if bytes >= 1_048_576 {
            return String(format: "%.1f MB", Double(bytes) / 1_048_576)
        } else {
            return String(format: "%.0f KB", Double(bytes) / 1024)
        }
    }
}
