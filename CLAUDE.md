# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Photo Culler — macOS SwiftUI 桌面应用，用于摄影师快速筛选 RAW 照片。用户选择文件夹后逐张浏览照片并评价（合格/糟糕），完成后可批量删除糟糕照片（含 RAW 和输出格式）。

## Build & Run

Xcode 项目，无外部依赖，仅使用 Foundation / SwiftUI / AppKit / Observation 框架。

```bash
# 命令行构建
xcodebuild -project "photo culler.xcodeproj" -scheme "photo culler" -destination 'platform=macOS,arch=arm64' build

# 或在 Xcode 中: Cmd+B 构建, Cmd+R 运行, Cmd+U 测试
```

部署目标: macOS 15.7+（使用 `@Observable` 宏）。

## Architecture

MVVM 架构，所有源码在 `photo culler/` 目录下：

- **`photo_cullerApp.swift`** — App 入口；`AppDelegate` 实现最后窗口关闭时退出 App；App 级别创建 `ExtensionSettings`（`@State`）并通过 `.environment()` 注入；使用 `ViewModelFocusedKey`（`@FocusedValue`）让菜单命令访问当前窗口的 ViewModel；菜单含 **File > Open…**（Cmd+O）和 **Photo > Delete Bad Photos…**（Cmd+D）
- **Models/** — `PhotoItem`（照片数据模型，按 basename 聚合 RAW + 输出文件；含运行时填充的 `fileHashes: [String]` 字段（哈希模式下为各关联文件前 4 MB SHA-256 hex，路径模式下保持空 `[]`）；含 `pathKey` 计算属性，返回 `(rawURL ?? outputURL)?.deletingPathExtension().path ?? id`，即去扩展名的绝对路径，为路径模式下的存储 key）、`Rating`（`.good` / `.bad` 枚举，Codable）、`ExtensionSettings`（`@Observable` class，管理可配置的 RAW/输出扩展名及 `matchingMode: MatchingMode`，均持久化至 `UserDefaults`）、`MatchingMode`（`enum`，定义于 `ExtensionSettings.swift`；`.hash` = 按文件内容 SHA-256 存储评价（默认，抗路径变动）；`.path` = 按文件绝对路径存储（跳过哈希计算，加载更快，但路径变动后评价失效））
- **ViewModels/** — `PhotoCullerViewModel`（`@Observable`，管理照片列表、当前索引、评价、删除流程等全部业务状态；含 `showDeletionResult` / `deletionResultMessage` 属性驱动删除完成提示；含 `isLoadingFolder` 属性驱动加载 spinner；含 `matchingMode: MatchingMode` 属性，在 `loadFolder()` 开头锁定，会话期间不受 Settings 改变影响；`loadFolder()` 为 `async`，哈希模式下用 `withTaskGroup` 并发计算哈希，路径模式下跳过哈希计算；在 `init` 中订阅 `NotificationCenter` 的 `.ratingsDidChange` 通知，收到时调用 `syncRatingsFromStore(changedKeys:)` 精准更新本窗口 `photos` 中受影响照片的 rating，实现多窗口实时同步）
- **Views/** — `ContentView`（根视图，内部用 `@State` 创建 `PhotoCullerViewModel`，通过 `.environment()` + `.focusedSceneValue()` 双重注入；三态切换：加载中显示 spinner / 已加载显示审阅视图 / 未加载显示文件夹选择）、`PhotoReviewView`（含两个 alert：全部评价完成 + 删除完成）、`PhotoDisplayView`（图片显示，支持捏合/滚轮缩放 1x–20x、双击缩放到 2.5x/复位、拖动平移；使用 `NSViewRepresentable` + ImageIO 提取 RAW 缩略图）、`BottomControlBar`、`ProgressBarView`、`FolderSelectionView`、`ThumbnailStripView`（右侧悬停展开的缩略图条，显示全部照片及评价徽章，点击跳转）、`SettingsView`（RAW/输出扩展名设置窗口）、`ExtensionListEditor`（扩展名列表编辑组件）
- **Services/** — `PhotoScanner`（扫描文件夹，按 basename 分组 RAW/输出文件）、`FileHasher`（`actor`，单例 `shared`；`hash(for:)` 为 `async`，缓存命中在 actor 上快速返回，缓存未命中通过 `Task.detached` 并发执行文件 I/O；`computeHash` 为 `nonisolated static` 可在任意线程调用；`persistCache()` 快照后在 background detached task 中异步写盘；磁盘缓存路径 `~/Library/Caches/com.ninzero.photo-culler/hash_cache.json`）、`RatingStore`（`@MainActor @Observable final class`，单例 `shared`；app 启动时从磁盘加载一次，`ratings: [String: Rating]` 为进程内唯一真相；key 可为 64 位 hex（哈希模式）或以 `/` 开头的绝对路径去扩展名（路径模式），两者天然不冲突，共存于同一 JSON；`applyRating(_:forKeys:)` 更新内存 + post `.ratingsDidChange`（userInfo 携带 `changedKeys: Set<String>`）+ `Task.detached` 异步写盘；`currentFolderKeys: Set<String>` 记录当前文件夹所有照片的 key；`clearAll()` 同理；磁盘路径 `~/Library/Application Support/com.ninzero.photo-culler/ratings.json`）、`AuditLogger`（全局审计日志至 `~/Library/Application Support/com.ninzero.photo-culler/audit.log`，每条含文件夹名）、`PhotoDeleter`（安全删除 + 审计，返回 `DeletionResult`）

## Key Data Flow

1. 用户通过 `NSOpenPanel` 选择文件夹
2. `PhotoScanner` 按 basename 将 `.ARW/.DNG/.RAW` 和 `.JPG/.JPEG/.HIF` 分组为 `PhotoItem`
3. `loadFolder()` 锁定 `matchingMode`（来自 `ExtensionSettings`）；**哈希模式**下用 `withTaskGroup` 并发调用 `FileHasher.shared.hash(for:)` 计算文件哈希，**路径模式**下跳过哈希计算（`fileHashes` 保持空 `[]`）；加载期间 `isLoadingFolder = true`，ContentView 显示 spinner
4. （哈希模式）`FileHasher`（actor）对每个请求：缓存命中直接返回，缓存未命中通过 `Task.detached` 在 cooperative thread pool 上并发读取文件前 4 MB 并计算 SHA-256
5. 全部加载完成后，按当前模式的 key（hash 或 pathKey）从 `RatingStore.shared.ratings` 恢复已有评价
6. ViewModel 跳转到第一张未评价照片
7. 评价后自动保存 JSON + 写审计日志 + 自动跳转下一张未评价照片
8. 确认删除弹窗可通过两种方式触发：
   - 自动：全部照片评价完成后自动弹出
   - 手动：菜单栏 **Photo → Delete Bad Photos…**（有 Bad 照片时可用）

## Conventions

- 持久化路径：
  - 用户评价（不可丢失）：`~/Library/Application Support/com.ninzero.photo-culler/ratings.json`（key = 64 位 hex SHA-256（哈希模式）或去扩展名绝对路径（路径模式），两者共存于同一文件，天然不冲突）
  - 审计日志：`~/Library/Application Support/com.ninzero.photo-culler/audit.log`（每条含文件夹名前缀）
  - 哈希缓存（可重建）：`~/Library/Caches/com.ninzero.photo-culler/hash_cache.json`
- **匹配模式**（`MatchingMode`）：用户可在 Settings 切换，切换后下次打开文件夹时生效（与扩展名设置一致）
  - **Hash 模式**（默认）：`PhotoItem.fileHashes` 由 `FileHasher` 并发填充（RAW + 输出文件各自前 4 MB SHA-256），评价以任意一个 hash 为全局唯一键（写入时同时写入所有 hash），文件夹移动/重命名、或删除 RAW 只保留输出文件后评价依然有效
  - **Path 模式**：以 `(rawURL ?? outputURL)?.deletingPathExtension().path`（即 `PhotoItem.pathKey`）为 key，跳过哈希计算，加载更快，但路径变动后评价失效
- 显示照片时优先使用输出格式（HIF/JPG），其次 RAW
- 键盘快捷键：左右箭头导航，上箭头=合格，下箭头=糟糕
- 菜单快捷键：Cmd+O 打开文件夹，Cmd+D 触发删除确认
- 菜单栏：**Photo → Delete Bad Photos…** 可在任意时刻触发删除确认（未加载文件夹或无 Bad 照片时禁用）
- 所有删除操作必须有审计日志记录
- RAW 扩展名（默认）: `.3fr`, `.arw`, `.cr2`, `.cr3`, `.dng`, `.fff`, `.nef`, `.raf`, `.raw`, `.rwl`；输出扩展名: `.jpg`, `.jpeg`, `.hif`
- RAW/输出扩展名用户可在 **Settings** 窗口自定义，持久化至 `UserDefaults`（`rawExtensions` / `outputExtensions` key）
- 匹配模式用户可在 **Settings** 窗口切换（`matchingMode` key），默认为 Hash 模式
