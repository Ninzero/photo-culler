# Photo Culler

macOS 桌面应用，帮助摄影师快速筛选 RAW 照片。选择文件夹后逐张浏览，标记合格或糟糕，最后批量删除糟糕照片（RAW 和输出格式同步删除）。

## 系统要求

- macOS 15.7+
- Xcode 16+（仅构建需要）

## 构建

无外部依赖，直接用 Xcode 打开 `photo culler.xcodeproj` 后构建运行，或使用命令行：

```bash
xcodebuild -project "photo culler.xcodeproj" -scheme "photo culler" build
```

## 功能

### 筛选流程

1. `⌘+O` 或点击界面按钮选择照片文件夹
2. 应用按文件名（basename）将 RAW 与输出格式配对；哈希模式下并发计算文件哈希，路径模式下跳过哈希直接加载
3. 逐张审阅，用键盘快速评价
4. 全部评价完成后自动弹出删除确认，或随时通过 `⌘+D` 手动触发

### 键盘快捷键

| 按键 | 操作 |
| ------ | ------ |
| `←` / `→` | 上一张 / 下一张 |
| `↑` | 标记为合格 |
| `↓` | 标记为糟糕 |
| `⌘+D` | 删除糟糕照片… |

### 图片查看

- 捏合手势或滚轮缩放（1x–20x）
- 双击放大至 2.5x / 再次双击复位
- 拖动平移
- 优先显示输出格式（HIF/JPG），无输出格式时显示 RAW 缩略图

### 评价持久化

支持两种匹配模式，可在 Settings 切换，切换后下次打开文件夹时生效：

- **Hash 模式**（默认）：以文件内容 SHA-256（前 4 MB）为 key，文件夹移动或重命名后评价依然有效
- **Path 模式**：以文件绝对路径（去扩展名）为 key，跳过哈希计算、加载更快，但路径变动后评价失效

### 右侧缩略图条

悬停右侧边缘展开，显示全部照片及评价徽章，点击可直接跳转。

### 自定义扩展名与匹配模式

在 Settings 窗口可自定义 RAW 和输出格式扩展名，以及切换匹配模式（Hash / Path）。

默认 RAW 扩展名：`.3fr` `.arw` `.cr2` `.cr3` `.dng` `.fff` `.nef` `.raf` `.raw` `.rwl`

默认输出扩展名：`.jpg` `.jpeg` `.hif`

## 数据存储

所有删除操作均记录审计日志。哈希缓存可安全删除，下次打开文件夹时自动重建。两种匹配模式的评价数据共存于同一 `ratings.json`，互不影响。

## 项目结构

```text
photo culler/
├── photo_cullerApp.swift       # App 入口，菜单定义
├── ContentView.swift           # 根视图
├── Models/
│   ├── PhotoItem.swift         # 照片数据模型（RAW + 输出文件配对）
│   ├── Rating.swift            # 评价枚举（.good / .bad）
│   └── ExtensionSettings.swift # 扩展名配置（UserDefaults 持久化）
├── ViewModels/
│   └── PhotoCullerViewModel.swift  # 业务状态管理
├── Views/
│   ├── PhotoReviewView.swift   # 审阅主界面
│   ├── PhotoDisplayView.swift  # 图片显示（缩放/平移）
│   ├── ThumbnailStripView.swift# 右侧缩略图条
│   ├── BottomControlBar.swift  # 底部操作栏
│   ├── ProgressBarView.swift   # 进度条
│   ├── FolderSelectionView.swift # 文件夹选择界面
│   ├── SettingsView.swift      # 设置窗口
│   └── ExtensionListEditor.swift # 扩展名列表编辑器
└── Services/
    ├── PhotoScanner.swift      # 文件夹扫描，按 basename 分组
    ├── FileHasher.swift        # 并发哈希计算（actor，磁盘缓存）
    ├── RatingStore.swift       # 评价 JSON 持久化
    ├── PhotoDeleter.swift      # 安全删除 + 审计
    └── AuditLogger.swift       # 审计日志
```
