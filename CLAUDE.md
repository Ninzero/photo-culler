# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Photo Culler — macOS SwiftUI 桌面应用，用于摄影师快速筛选 RAW 照片。用户选择文件夹后逐张浏览照片并评价（合格/糟糕），完成后可批量删除糟糕照片（含 RAW 和输出格式）。

## Build & Run

Xcode 项目，无外部依赖，仅使用 Foundation / SwiftUI / AppKit / Observation 框架。

```bash
# 命令行构建
xcodebuild -project "photo culler.xcodeproj" -scheme "photo culler" build

# 或在 Xcode 中: Cmd+B 构建, Cmd+R 运行, Cmd+U 测试
```

部署目标: macOS 15.7+（使用 `@Observable` 宏）。

## Architecture

MVVM 架构，所有源码在 `photo culler/` 目录下：

- **`photo_cullerApp.swift`** — App 入口；`AppDelegate` 实现最后窗口关闭时退出 App；App 级别创建 `ExtensionSettings`（`@State`）并通过 `.environment()` 注入；使用 `ViewModelFocusedKey`（`@FocusedValue`）让菜单命令访问当前窗口的 ViewModel；菜单含 **File > Open…**（Cmd+O）和 **Photo > Delete Bad Photos…**（Cmd+D）
- **Models/** — `PhotoItem`（照片数据模型，按 basename 聚合 RAW + 输出文件；含运行时填充的 `fileHash: String?` 字段，为主文件前 4 MB 的 SHA-256 hex）、`Rating`（`.good` / `.bad` 枚举，Codable）、`ExtensionSettings`（`@Observable` class，管理可配置的 RAW/输出扩展名，持久化至 `UserDefaults`）
- **ViewModels/** — `PhotoCullerViewModel`（`@Observable`，管理照片列表、当前索引、评价、删除流程等全部业务状态；含 `showDeletionResult` / `deletionResultMessage` 属性驱动删除完成提示；含 `isLoadingFolder` 属性驱动加载 spinner；`loadFolder()` 为 `async`，用 `withTaskGroup` 并发计算哈希）
- **Views/** — `ContentView`（根视图，内部用 `@State` 创建 `PhotoCullerViewModel`，通过 `.environment()` + `.focusedSceneValue()` 双重注入；三态切换：加载中显示 spinner / 已加载显示审阅视图 / 未加载显示文件夹选择）、`PhotoReviewView`（含两个 alert：全部评价完成 + 删除完成）、`PhotoDisplayView`（图片显示，支持捏合/滚轮缩放 1x–20x、双击缩放到 2.5x/复位、拖动平移；使用 `NSViewRepresentable` + ImageIO 提取 RAW 缩略图）、`BottomControlBar`、`ProgressBarView`、`FolderSelectionView`、`ThumbnailStripView`（右侧悬停展开的缩略图条，显示全部照片及评价徽章，点击跳转）、`SettingsView`（RAW/输出扩展名设置窗口）、`ExtensionListEditor`（扩展名列表编辑组件）
- **Services/** — `PhotoScanner`（扫描文件夹，按 basename 分组 RAW/输出文件）、`FileHasher`（`actor`，单例 `shared`；`hash(for:)` 为 `async`，缓存命中在 actor 上快速返回，缓存未命中通过 `Task.detached` 并发执行文件 I/O；`computeHash` 为 `nonisolated static` 可在任意线程调用；`persistCache()` 快照后在 background detached task 中异步写盘；磁盘缓存路径 `~/Library/Caches/com.ninzero.photo-culler/hash_cache.json`）、`RatingStore`（全局 JSON 持久化至 `~/Library/Application Support/com.ninzero.photo-culler/ratings.json`，key 为文件内容 SHA-256 hex）、`AuditLogger`（全局审计日志至 `~/Library/Application Support/com.ninzero.photo-culler/audit.log`，每条含文件夹名）、`PhotoDeleter`（安全删除 + 审计，返回 `DeletionResult`）

## Key Data Flow

1. 用户通过 `NSOpenPanel` 选择文件夹
2. `PhotoScanner` 按 basename 将 `.ARW/.DNG/.RAW` 和 `.JPG/.JPEG/.HIF` 分组为 `PhotoItem`
3. `loadFolder()` 用 `withTaskGroup` 并发调用 `FileHasher.shared.hash(for:)`（每张照片一个 task）；main actor 在 `await withTaskGroup` 期间挂起，UI 保持响应；加载期间 `isLoadingFolder = true`，ContentView 显示 spinner
4. `FileHasher`（actor）对每个请求：缓存命中直接返回，缓存未命中通过 `Task.detached` 在 cooperative thread pool 上并发读取文件前 4 MB 并计算 SHA-256
5. 全部哈希计算完成后，`RatingStore` 从 App Support 全局 JSON 恢复已有评价（以 SHA-256 为 key）
6. ViewModel 跳转到第一张未评价照片
5. 评价后自动保存 JSON + 写审计日志 + 自动跳转下一张未评价照片
6. 确认删除弹窗可通过两种方式触发：
   - 自动：全部照片评价完成后自动弹出
   - 手动：菜单栏 **Photo → Delete Bad Photos…**（有 Bad 照片时可用）

## Conventions

- 持久化路径：
  - 用户评价（不可丢失）：`~/Library/Application Support/com.ninzero.photo-culler/ratings.json`（key = 文件内容 SHA-256 hex）
  - 审计日志：`~/Library/Application Support/com.ninzero.photo-culler/audit.log`（每条含文件夹名前缀）
  - 哈希缓存（可重建）：`~/Library/Caches/com.ninzero.photo-culler/hash_cache.json`
- `PhotoItem.fileHash` 在 `loadFolder()` 时由 `FileHasher` 并发填充（前 4 MB SHA-256），评价以此为全局唯一键，文件夹移动/重命名后评价依然有效
- 显示照片时优先使用输出格式（HIF/JPG），其次 RAW
- 键盘快捷键：左右箭头导航，上箭头=合格，下箭头=糟糕
- 菜单快捷键：Cmd+O 打开文件夹，Cmd+D 触发删除确认
- 菜单栏：**Photo → Delete Bad Photos…** 可在任意时刻触发删除确认（未加载文件夹或无 Bad 照片时禁用）
- 所有删除操作必须有审计日志记录
- RAW 扩展名（默认）: `.3fr`, `.arw`, `.cr2`, `.cr3`, `.dng`, `.fff`, `.nef`, `.raf`, `.raw`, `.rwl`；输出扩展名: `.jpg`, `.jpeg`, `.hif`
- RAW/输出扩展名用户可在 **Settings** 窗口自定义，持久化至 `UserDefaults`（`rawExtensions` / `outputExtensions` key）
