# Photo Culler

macOS 桌面应用，帮助摄影师快速筛选 RAW 照片。选择文件夹后逐张浏览并标记合格或糟糕，然后批量删除糟糕照片、为照片按系列名批量改名，或把合格照片复制到其他目录。同名的 RAW 与输出格式（JPG / HIF 等）始终作为一张照片一起处理。

## 系统要求

- macOS 14.0+
- Xcode 26+（仅构建需要）

## 构建

无外部依赖，直接用 Xcode 打开 `photo culler.xcodeproj` 后构建运行，或使用命令行：

```bash
xcodebuild -project "photo culler.xcodeproj" -scheme "photo culler" -destination 'platform=macOS,arch=arm64' build
```

## 功能

各功能的完整行为规范见 [`openspec/specs/`](openspec/specs/)。

### 筛选流程

1. `⌘O` 或点击界面按钮选择照片文件夹，应用按文件名（basename）将 RAW 与输出格式配对，并按文件名自然顺序排列
2. 自动定位到第一张未评价的照片，用方向键逐张评价；对同一张照片重复同一评价即撤销
3. 全部评价完成后弹出提示，可直接删除糟糕照片，或先进入 Rejected Only 模式复查

### 键盘快捷键

| 按键 | 操作 |
| ------ | ------ |
| `←` / `→` | 上一张 / 下一张 |
| `↑` | 标记为合格（再按一次撤销） |
| `↓` | 标记为糟糕（再按一次撤销） |
| `⌘O` | 打开文件夹… |
| `⌘D` | 删除糟糕照片… |
| `⌘R` | 批量改名… |
| `⇧⌘C` | 复制合格照片… |
| `⇧⌘M` | 循环切换查看模式 |

### 查看模式

在 **View → Mode** 中选择，或用 `⇧⌘M` 循环切换：

- **All Photos**（默认）：全部照片
- **Unrated Only**：只看未评价照片，用于补评
- **Rejected Only**：只看糟糕照片，用于删除前复查
- **Prized Only**：只看合格照片

### 批量操作

均在 **Photo** 菜单中，执行前需确认，完成后汇报结果：

- **删除糟糕照片**：删除每张糟糕照片的 RAW 与输出文件
- **批量改名**：按 `<系列名>-<序号>` 重命名当前文件夹的全部照片（如 `Wedding-001`），改名后评价保留；删除完成后也可直接进入改名
- **复制合格照片**：将合格照片的全部文件复制到指定目录（默认为当前文件夹下的 `prized/`），可选择是否覆盖已有文件

### 图片查看

- 捏合手势或滚轮缩放（1x–20x），双击放大至 2.5x / 再次双击复位，拖动平移
- 优先显示输出格式，没有输出文件时显示 RAW 内嵌预览
- 鼠标悬停窗口左侧边缘：展开 EXIF 信息面板（拍摄参数、相机与镜头、文件信息、GPS 等）
- 鼠标悬停窗口右侧边缘：展开缩略图条，显示当前模式下的照片及评价徽章，点击可跳转

### 评价持久化

评价自动保存，重新打开同一文件夹时自动恢复；多个窗口打开同一文件夹时评价实时同步。支持两种匹配模式：

- **Hash 模式**（默认）：以文件内容 SHA-256（前 4 MB）为 key，文件夹移动或重命名、删除 RAW 只保留输出文件后，评价依然有效
- **Path 模式**：以文件绝对路径（去扩展名）为 key，跳过哈希计算、加载更快，但在应用外移动或重命名后评价失效

两种模式的评价分开保存、互不影响。

### 设置

在 **Settings**（`⌘,`）窗口中：

- 自定义 RAW 与输出格式扩展名，切换匹配模式，或恢复默认设置；修改在下次打开文件夹时生效
- 清除全部评价、清除当前文件夹评价、清除哈希缓存

默认 RAW 扩展名：`.3fr` `.arw` `.cr2` `.cr3` `.dng` `.fff` `.nef` `.raf` `.raw` `.rwl`

默认输出扩展名：`.jpg` `.jpeg` `.hif`

## 数据存储

应用启用了 App Sandbox，数据保存在 `~/Library/Containers/com.ninzero.photo-culler/Data/Library/` 下：

| 文件 | 位置 | 说明 |
| ------ | ------ | ------ |
| `ratings.json` | `Application Support/com.ninzero.photo-culler/` | 全部评价，两种匹配模式的数据共存 |
| `audit.log` | `Application Support/com.ninzero.photo-culler/` | 审计日志，记录评价变化及所有删除、改名、复制操作，只追加 |
| `hash_cache.json` | `Caches/com.ninzero.photo-culler/` | 哈希缓存，可安全删除，下次打开文件夹时自动重建 |

只评价不会修改照片文件夹；只有删除、改名、复制会改动文件。

## 开发

MVVM 架构，源码位于 `photo culler/`，分为 `Models/`、`ViewModels/`、`Views/`、`Services/` 四层。代码结构说明见 [`CLAUDE.md`](CLAUDE.md)，功能行为以 [`openspec/specs/`](openspec/specs/) 为准。
