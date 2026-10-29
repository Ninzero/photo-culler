# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Photo Culler — macOS SwiftUI 桌面应用，供摄影师快速筛选 RAW 照片：选择文件夹后逐张评价（合格 / 糟糕），再对结果批量删除、改名或复制。

## Specs: OpenSpec 是行为的权威来源

- 产品行为、交互细节与不变量以 `openspec/specs/<capability>/spec.md` 为准。本文件只描述代码结构；两者冲突时以 spec 为准，并修正本文件。
- 修改用户可见行为时走 OpenSpec 流程（`openspec-*` skills），产出物使用简体中文（见 `openspec/config.yaml`）。
- `openspec/changes/` 被 `.gitignore` 忽略，只有 `openspec/specs/` 入库。

## Build & Run

```bash
xcodebuild -project "photo culler.xcodeproj" -scheme "photo culler" -destination 'platform=macOS,arch=arm64' build
```

- 需要 Xcode 26+（用到 Swift 6.2 的默认隔离设置）。单一 target，无外部依赖，无测试 target：改动靠构建 + 手动运行验证。
- 部署目标 macOS 14.0；启用 App Sandbox（用户所选文件读写权限）。
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` + Approachable Concurrency：类型默认隔离在 MainActor，需要离开主线程的代码（文件 I/O、哈希、EXIF 解析、审计日志）必须显式 `nonisolated`、放进 `actor`，或用 `Task.detached` 执行。

## Architecture

MVVM，源码在 `photo culler/`：

- `photo_cullerApp.swift` — App 入口；所有菜单命令、快捷键及其可用性判断都集中在这里。菜单通过 `@FocusedValue(\.viewModel)` 拿到当前 key window 的 ViewModel；App 级的 `ExtensionSettings` 经 `.environment()` 注入。
- `ContentView.swift` — 每个窗口的根视图，用 `@State` 持有本窗口的 `PhotoCullerViewModel`，并同时以 `.environment()` 和 `.focusedSceneValue()` 暴露。窗口成为 key 时把本窗口照片的 key 同步到 `RatingStore`（供「清除当前文件夹评价」使用）。
- `Models/` — `PhotoItem`（一张照片 = 同 basename 的全部 RAW 与输出文件，按 `fileURLs` 统一访问；外加运行时的评价与哈希）、`Rating`、`ExifData`；`ExtensionSettings`（`@Observable`，用户设置持久化到 `UserDefaults`，`MatchingMode` 也定义在这里）。
- `ViewModels/PhotoCullerViewModel.swift` — 单个窗口的全部业务状态和流程编排：加载文件夹、导航、查看模式（`ViewMode`）、评价，以及删除 / 改名 / 复制的触发和结果展示。
- `Services/` — 不含 UI，由 ViewModel 调用：
  - `PhotoScanner` — 扫描文件夹，分组并排序为 `[PhotoItem]`
  - `FileHasher` — `actor`，Hash 模式下计算文件哈希，带磁盘缓存
  - `RatingStore` — `@MainActor` 单例，评价的持久化与跨窗口通知
  - `PhotoDeleter` / `PhotoRenamer` / `PhotoCopier` — 文件变更操作，各自返回 `*Result`（含 `summary`）
  - `ExifReader` — `actor`，读取 EXIF，带 LRU 缓存
  - `AuditLogger` — 追加写审计日志
- `Views/` — SwiftUI 视图，读取 ViewModel 状态并回调其方法。`PhotoReviewView` 是审阅主界面，承载各 alert / sheet 以及左侧 EXIF、右侧缩略图两个悬停面板。

## Structural Conventions

- **评价的唯一真相是 `RatingStore.shared.ratings`**，`PhotoItem.rating` 只是各窗口的缓存。写评价一律调用 `RatingStore.applyRating(_:forKeys:)`：它会 post `.ratingsDidChange`（`userInfo["changedKeys"]`），每个 ViewModel 收到后只刷新受影响的照片。
- **评价 key 由加载文件夹时锁定的 `matchingMode` 决定**：Hash 模式用 `PhotoItem.fileHashes`，Path 模式用 `PhotoItem.pathKey`。读、写、清除评价都必须按同一模式取 key（ViewModel 与 `ContentView` 中有多处这样的分支）。改变文件路径的操作在 Path 模式下要迁移 key（参见 `performRename`）。
- **文件变更操作放在 `Services/`**：逐文件处理，单个文件失败不中断，每一步都写审计日志，最后返回汇总结果。新增此类操作时沿用同样的模式。
- 耗时操作不阻塞主线程：哈希并发计算（`withTaskGroup` + `FileHasher`），复制在 `Task.detached` 中执行，并用 `isCopying` 阻止其他文件操作。
- 持久化文件位于 Application Support / Caches 下的 `com.ninzero.photo-culler/` 子目录（沙盒构建下实际在 `~/Library/Containers/com.ninzero.photo-culler/Data/Library/…`）：
  - `ratings.json` — 用户评价，不可丢失；hash key 与 path key 共存于同一文件
  - `audit.log` — 只追加
  - `hash_cache.json`（Caches）— 可重建
