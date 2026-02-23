import Foundation

struct RenameResult {
    let renamedPhotos: [PhotoItem]
    let renamedFileCount: Int
    let failedFiles: [(String, Error)]

    var summary: String {
        var lines: [String] = []
        lines.append("Renamed \(renamedFileCount) file(s).")
        if !failedFiles.isEmpty {
            lines.append("Failed to rename \(failedFiles.count) file(s):")
            for (name, error) in failedFiles {
                lines.append("  \(name): \(error.localizedDescription)")
            }
        }
        return lines.joined(separator: "\n")
    }
}

struct PhotoRenamer {
    /// 校验系列名：非空，仅含汉字、ASCII字母、数字、连字符、下划线
    static func isValidSeriesName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        for scalar in trimmed.unicodeScalars {
            let v = scalar.value
            let isCJK = (v >= 0x4E00 && v <= 0x9FFF)
                     || (v >= 0x3400 && v <= 0x4DBF)
                     || (v >= 0x20000 && v <= 0x2A6DF)
            let isLetter = (v >= 0x41 && v <= 0x5A) || (v >= 0x61 && v <= 0x7A)
            let isDigit = v >= 0x30 && v <= 0x39
            let isSeparator = v == 0x2D || v == 0x5F  // '-' or '_'
            if !isCJK && !isLetter && !isDigit && !isSeparator { return false }
        }
        return true
    }

    static func rename(
        photos: [PhotoItem],
        seriesName: String,
        in folderURL: URL
    ) -> RenameResult {
        guard !photos.isEmpty else {
            return RenameResult(renamedPhotos: photos, renamedFileCount: 0, failedFiles: [])
        }

        let totalCount = photos.count
        let digitWidth = max(3, String(totalCount).count)
        let fileManager = FileManager.default
        let sessionID = String(UUID().uuidString.prefix(8)).lowercased()

        // 收集所有源文件 URL（用于冲突检测）
        var sourceURLSet: Set<URL> = []
        for photo in photos {
            if let u = photo.rawURL    { sourceURLSet.insert(u.standardized) }
            if let u = photo.outputURL { sourceURLSet.insert(u.standardized) }
        }

        struct RenameOp {
            let photoIndex: Int
            let isRaw: Bool
            let sourceURL: URL
            let tempURL: URL
            let targetURL: URL
        }

        var ops: [RenameOp] = []
        var conflictErrors: [(String, Error)] = []

        for (i, photo) in photos.enumerated() {
            let padded = String(format: "%0\(digitWidth)d", i + 1)
            let targetBasename = "\(seriesName)-\(padded)"

            let pairs: [(URL, Bool)] = [
                photo.rawURL.map    { ($0, true)  },
                photo.outputURL.map { ($0, false) }
            ].compactMap { $0 }

            for (sourceURL, isRaw) in pairs {
                let ext = sourceURL.pathExtension
                let targetURL = folderURL.appendingPathComponent("\(targetBasename).\(ext)")

                // 幂等：源与目标相同时跳过
                if sourceURL.standardized == targetURL.standardized { continue }

                // 外部冲突：目标已存在且不属于本批次
                if fileManager.fileExists(atPath: targetURL.path),
                   !sourceURLSet.contains(targetURL.standardized) {
                    struct ConflictError: LocalizedError {
                        let target: String
                        var errorDescription: String? {
                            "'\(target)' already exists and is not part of this batch"
                        }
                    }
                    conflictErrors.append((
                        sourceURL.lastPathComponent,
                        ConflictError(target: targetURL.lastPathComponent)
                    ))
                    AuditLogger.log(
                        "RENAME_CONFLICT: \(sourceURL.lastPathComponent) -> \(targetURL.lastPathComponent) blocked by external file",
                        in: folderURL
                    )
                }

                let suffix = isRaw ? "r" : "o"
                let tempURL = folderURL.appendingPathComponent(
                    ".tmp_rnm_\(sessionID)_\(i)_\(suffix).\(ext)"
                )
                ops.append(RenameOp(
                    photoIndex: i, isRaw: isRaw,
                    sourceURL: sourceURL, tempURL: tempURL, targetURL: targetURL
                ))
            }
        }

        if !conflictErrors.isEmpty {
            AuditLogger.log("RENAME_ABORTED: \(conflictErrors.count) external conflict(s)", in: folderURL)
            return RenameResult(renamedPhotos: photos, renamedFileCount: 0, failedFiles: conflictErrors)
        }

        // 阶段一：源文件 → 临时名
        var phase1Success: [RenameOp] = []
        var failedFiles: [(String, Error)] = []

        for op in ops {
            do {
                try fileManager.moveItem(at: op.sourceURL, to: op.tempURL)
                phase1Success.append(op)
            } catch {
                failedFiles.append((op.sourceURL.lastPathComponent, error))
                AuditLogger.log(
                    "RENAME_PHASE1_FAILED: \(op.sourceURL.lastPathComponent) - \(error.localizedDescription)",
                    in: folderURL
                )
            }
        }

        // 阶段二：临时名 → 最终目标名
        var renamedFileCount = 0
        var newRawURLs: [Int: URL] = [:]
        var newOutputURLs: [Int: URL] = [:]

        for op in phase1Success {
            do {
                try fileManager.moveItem(at: op.tempURL, to: op.targetURL)
                renamedFileCount += 1
                AuditLogger.log(
                    "RENAMED: \(op.sourceURL.lastPathComponent) -> \(op.targetURL.lastPathComponent)",
                    in: folderURL
                )
                if op.isRaw {
                    newRawURLs[op.photoIndex] = op.targetURL
                } else {
                    newOutputURLs[op.photoIndex] = op.targetURL
                }
            } catch {
                failedFiles.append((op.tempURL.lastPathComponent, error))
                AuditLogger.log(
                    "RENAME_PHASE2_FAILED: \(op.sourceURL.lastPathComponent) -> \(op.targetURL.lastPathComponent) (stuck at temp name) - \(error.localizedDescription)",
                    in: folderURL
                )
            }
        }

        // 用新 URL 构建更新后的 photos 数组
        var renamedPhotos = photos
        for i in renamedPhotos.indices {
            if let url = newRawURLs[i]    { renamedPhotos[i].rawURL    = url }
            if let url = newOutputURLs[i] { renamedPhotos[i].outputURL = url }
        }

        AuditLogger.log(
            "RENAME_COMPLETE: \(renamedFileCount) file(s) renamed, \(failedFiles.count) failed",
            in: folderURL
        )
        return RenameResult(
            renamedPhotos: renamedPhotos,
            renamedFileCount: renamedFileCount,
            failedFiles: failedFiles
        )
    }
}
