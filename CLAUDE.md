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

- **`photo_cullerApp.swift`** — App 入口，在 App 级别创建 `PhotoCullerViewModel`（`@State`），通过 `.environment(viewModel)` 注入给子视图；同时在 `WindowGroup` 上挂载 `.commands { CommandMenu("Photo") { ... } }` 自定义菜单
- **Models/** — `PhotoItem`（照片数据模型，按 basename 聚合 RAW + 输出文件）、`Rating`（`.good` / `.bad` 枚举，Codable）
- **ViewModels/** — `PhotoCullerViewModel`（`@Observable`，管理照片列表、当前索引、评价、删除流程等全部业务状态）
- **Views/** — `ContentView`（根视图，通过 `@Environment(PhotoCullerViewModel.self)` 接收 viewModel，切换文件夹选择/照片审阅）、`PhotoReviewView`、`PhotoDisplayView`、`BottomControlBar`、`ProgressBarView`、`FolderSelectionView`
- **Services/** — `PhotoScanner`（扫描文件夹，按 basename 分组 RAW/输出文件）、`RatingStore`（JSON 持久化至 `.photo_culler_ratings.json`）、`AuditLogger`（审计日志至 `.photo_culler_audit.log`）、`PhotoDeleter`（安全删除 + 审计）

## Key Data Flow

1. 用户通过 `NSOpenPanel` 选择文件夹
2. `PhotoScanner` 按 basename 将 `.ARW/.DNG/.RAW` 和 `.JPG/.JPEG/.HIF` 分组为 `PhotoItem`
3. `RatingStore` 从隐藏 JSON 文件恢复已有评价
4. ViewModel 跳转到第一张未评价照片
5. 评价后自动保存 JSON + 写审计日志 + 自动跳转下一张未评价照片
6. 确认删除弹窗可通过两种方式触发：
   - 自动：全部照片评价完成后自动弹出
   - 手动：菜单栏 **Photo → Delete Bad Photos…**（有 Bad 照片时可用）

## Conventions

- 持久化文件存放在用户选择的文件夹内（隐藏文件 `.photo_culler_ratings.json` 和 `.photo_culler_audit.log`）
- 显示照片时优先使用输出格式（HIF/JPG），其次 RAW
- 键盘快捷键：左右箭头导航，上箭头=合格，下箭头=糟糕
- 菜单栏：**Photo → Delete Bad Photos…** 可在任意时刻触发删除确认（未加载文件夹或无 Bad 照片时禁用）
- 所有删除操作必须有审计日志记录
- RAW 扩展名（默认）: `.3fr`, `.arw`, `.cr2`, `.cr3`, `.dng`, `.fff`, `.nef`, `.raf`, `.raw`, `.rwl`；输出扩展名: `.jpg`, `.jpeg`, `.hif`

## Test Data

`data/example_photos/` 包含真实照片样本（已在 `.gitignore` 中排除），可用于本地测试。
