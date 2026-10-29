# photo-grouping Specification

## Purpose

定义如何从用户选择的文件夹中识别照片：将同一次拍摄产生的 RAW 文件与输出文件（如 JPG、HIF）归并为一张照片，作为评价、删除、改名、复制等操作的基本单位。

## Requirements

### Requirement: 按 basename 将 RAW 与输出文件配对
系统 SHALL 扫描用户所选文件夹的顶层文件，将去掉扩展名后文件名（basename）相同的 RAW 文件与输出文件归并为同一张照片。一张照片 MAY 只有 RAW 文件或只有输出文件。扩展名匹配 SHALL 不区分大小写。

#### Scenario: RAW 与输出文件同名
- **WHEN** 文件夹中存在 `DSC00001.ARW` 与 `DSC00001.HIF`
- **THEN** 系统将二者识别为同一张照片，删除、改名、复制等操作同时作用于这两个文件

#### Scenario: 只有单一格式
- **WHEN** 文件夹中存在 `DSC00002.ARW`，但没有同名的输出文件
- **THEN** 系统仍将 `DSC00002` 识别为一张照片

#### Scenario: 扩展名大小写不同
- **WHEN** 文件夹中存在 `dsc00003.arw`
- **THEN** 系统按 RAW 扩展名 `ARW` 识别该文件

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
照片同时具有 RAW 与输出文件时，系统 SHALL 显示输出文件；只有 RAW 文件时，系统 SHALL 显示 RAW 文件的预览。

#### Scenario: RAW 与输出文件并存
- **WHEN** 当前照片同时有 `.ARW` 与 `.HIF` 文件
- **THEN** 主视图显示 `.HIF` 文件的内容

#### Scenario: 仅有 RAW
- **WHEN** 当前照片只有 `.ARW` 文件
- **THEN** 主视图显示该 RAW 文件的预览图
