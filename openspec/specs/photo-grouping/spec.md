# photo-grouping Specification

## Purpose

定义如何从用户选择的文件夹中识别照片：将同一次拍摄产生的 RAW 文件与输出文件（如 JPG、HIF）归并为一张照片，作为评价、删除、改名、复制等操作的基本单位。

## Requirements

### Requirement: 按 basename 将 RAW 与输出文件配对
系统 SHALL 扫描用户所选文件夹的顶层文件，将去掉扩展名后文件名（basename）相同的全部 RAW 文件与全部输出文件归并为同一张照片。一张照片 MAY 只有 RAW 文件或只有输出文件，也 MAY 包含多个 RAW 文件或多个输出文件。扩展名匹配 SHALL 不区分大小写。同一扩展名同时出现在 RAW 与输出扩展名列表中时，该扩展名的文件 SHALL 被视为 RAW 文件。

#### Scenario: RAW 与输出文件同名
- **WHEN** 文件夹中存在 `DSC00001.ARW` 与 `DSC00001.HIF`
- **THEN** 系统将二者识别为同一张照片，删除、改名、复制等操作同时作用于这两个文件

#### Scenario: 只有单一格式
- **WHEN** 文件夹中存在 `DSC00002.ARW`，但没有同名的输出文件
- **THEN** 系统仍将 `DSC00002` 识别为一张照片

#### Scenario: 扩展名大小写不同
- **WHEN** 文件夹中存在 `dsc00003.arw`
- **THEN** 系统按 RAW 扩展名 `ARW` 识别该文件

#### Scenario: 多个 RAW 与多个输出文件
- **WHEN** 文件夹中存在 `DSC00005.ARW`、`DSC00005.DNG`、`DSC00005.HIF` 与 `DSC00005.JPG`
- **THEN** 系统将这四个文件识别为同一张照片，删除、改名、复制等操作作用于全部四个文件

#### Scenario: 扩展名同时在两个列表中
- **WHEN** 用户将 `TIF` 同时加入 RAW 与输出扩展名列表，文件夹中存在 `DSC00006.TIF`
- **THEN** 系统将 `DSC00006.TIF` 视为 RAW 文件

### Requirement: 扫描范围
系统 SHALL 只扫描所选文件夹的直接子文件，不递归进入子文件夹，并 SHALL 忽略隐藏文件以及扩展名不在 RAW 或输出列表中的文件。

#### Scenario: 子文件夹中的照片
- **WHEN** 所选文件夹包含子文件夹 `prized/`，其中存有照片
- **THEN** 子文件夹中的照片不出现在照片列表中

#### Scenario: 无关文件
- **WHEN** 文件夹中存在 `.DS_Store`、`notes.txt` 或 `DSC00004.xmp`
- **THEN** 这些文件不被识别为照片，也不参与任何照片操作

### Requirement: 可配置的扩展名列表
系统 SHALL 允许用户分别配置 RAW 扩展名列表与输出扩展名列表，配置跨会话保留，并提供恢复默认值的操作。每个列表 SHALL 至少保留一个扩展名。修改 SHALL 在下次打开文件夹时生效，不影响已加载的文件夹。默认 RAW 扩展名为 `3FR`、`ARW`、`CR2`、`CR3`、`DNG`、`FFF`、`NEF`、`RAF`、`RAW`、`RWL`；默认输出扩展名为 `JPG`、`JPEG`、`HIF`。

#### Scenario: 新增扩展名
- **WHEN** 用户在输出扩展名列表中添加 `.tif`，然后重新打开文件夹
- **THEN** 文件夹中的 `.TIF` 文件被识别为输出文件

#### Scenario: 已加载的文件夹不受影响
- **WHEN** 文件夹已加载，用户随后修改扩展名列表
- **THEN** 当前照片列表保持不变，直到下次打开文件夹

#### Scenario: 恢复默认
- **WHEN** 用户执行恢复默认
- **THEN** 两个扩展名列表恢复为上述默认值

### Requirement: 显示时优先使用输出文件
照片有输出文件时，系统 SHALL 显示按照片内文件顺序排在第一个的输出文件；只有 RAW 文件时，系统 SHALL 显示按该顺序排在第一个的 RAW 文件的预览。

#### Scenario: RAW 与输出文件并存
- **WHEN** 当前照片同时有 `.ARW` 与 `.HIF` 文件
- **THEN** 主视图显示 `.HIF` 文件的内容

#### Scenario: 仅有 RAW
- **WHEN** 当前照片只有 `.ARW` 文件
- **THEN** 主视图显示该 RAW 文件的预览图

#### Scenario: 多个输出文件
- **WHEN** 当前照片有 `.ARW`、`.HIF` 与 `.JPG` 文件
- **THEN** 主视图显示 `.HIF` 文件的内容

#### Scenario: 多个 RAW 文件且没有输出文件
- **WHEN** 当前照片只有 `.DNG` 与 `.ARW` 文件
- **THEN** 主视图显示 `.ARW` 文件的预览图

### Requirement: 照片列表按 basename 自然顺序排列
系统 SHALL 按照片 basename 的自然顺序排列照片列表：basename 中的连续数字 SHALL 按数值大小比较，字母 SHALL 不区分大小写比较。

#### Scenario: 未补零的编号
- **WHEN** 文件夹中存在 `IMG_1`、`IMG_2`、`IMG_10` 三张照片
- **THEN** 照片列表顺序为 `IMG_1`、`IMG_2`、`IMG_10`

#### Scenario: 大小写不同
- **WHEN** 文件夹中存在 `img_01` 与 `IMG_02` 两张照片
- **THEN** `img_01` 排在 `IMG_02` 之前

#### Scenario: 已补零的编号
- **WHEN** 文件夹中存在 `DSC09999` 与 `DSC10000` 两张照片
- **THEN** `DSC09999` 排在 `DSC10000` 之前

### Requirement: 照片列表顺序确定
对同一组文件，系统 SHALL 每次加载都给出完全相同的照片列表顺序，basename 只差大小写或只差数字补零位数的照片也不例外。

#### Scenario: 重复打开同一文件夹
- **WHEN** 用户多次打开同一文件夹，期间文件没有变化
- **THEN** 每次的照片列表顺序都相同

#### Scenario: basename 只差大小写
- **WHEN** 文件夹中存在 `IMG_0001.ARW` 与 `img_0001.JPG`，它们被识别为两张照片
- **THEN** 两张照片在列表中的先后顺序每次加载都相同

#### Scenario: basename 只差补零位数
- **WHEN** 文件夹中存在 `photo-2` 与 `photo-02` 两张照片
- **THEN** 两张照片在列表中的先后顺序每次加载都相同

### Requirement: 照片内文件的顺序
照片包含多个文件时，系统 SHALL 按确定的顺序排列这些文件：RAW 文件在前，输出文件在后；同类文件按扩展名的字母顺序排列，不区分大小写。对同一组文件，这一顺序 SHALL 每次加载都相同。显示哪个文件以及 Hash 模式下读取评价的顺序均以此为准。

#### Scenario: RAW 与输出文件混合
- **WHEN** 一张照片包含 `DSC00007.JPG`、`DSC00007.DNG`、`DSC00007.JPEG`、`DSC00007.ARW` 与 `DSC00007.HIF`
- **THEN** 这些文件的顺序为 `ARW`、`DNG`、`HIF`、`JPEG`、`JPG`

#### Scenario: 扩展名大小写不一
- **WHEN** 一张照片包含输出文件 `DSC00008.jpg` 与 `DSC00008.HIF`
- **THEN** `DSC00008.HIF` 排在 `DSC00008.jpg` 之前

#### Scenario: 重复加载
- **WHEN** 用户多次打开同一文件夹，期间文件没有变化
- **THEN** 每张照片内文件的顺序每次都相同
