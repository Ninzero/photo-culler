# view-modes Specification

## Purpose

定义按评价状态过滤照片列表的查看模式，让用户可以只看未评价、糟糕或合格的照片，用于集中补评、复查待删照片或回看精选照片。

## Requirements

### Requirement: 四种查看模式
系统 SHALL 提供四种查看模式：All Photos（全部照片）、Unrated Only（仅未评价）、Rejected Only（仅糟糕）、Prized Only（仅合格），默认为 All Photos。过滤模式下的照片保持原列表顺序，导航、缩略图条与位置计数只作用于过滤后的照片。非 All Photos 模式下，系统 SHALL 显示当前模式及符合条件的照片数量；没有符合条件的照片时 SHALL 显示空状态说明。用户 SHALL 能直接选择某个模式，也能按 All Photos、Unrated Only、Rejected Only、Prized Only 的顺序循环切换。

#### Scenario: 进入 Rejected Only
- **WHEN** 文件夹中有 5 张糟糕照片，用户切换到 Rejected Only
- **THEN** 只能浏览这 5 张照片，界面标明当前模式与数量 5

#### Scenario: 空状态
- **WHEN** 文件夹中没有合格照片，用户切换到 Prized Only
- **THEN** 系统显示没有合格照片的说明

### Requirement: 过滤模式下的评价
在过滤模式下评价照片后，不再符合当前模式条件的照片 SHALL 立即从当前列表中移出，界面显示原位置上的下一张照片（原位置已超出列表末尾时显示最后一张）。在 Unrated Only 模式下评价完最后一张未评价照片时，系统 SHALL 给出与 All Photos 模式相同的全部评价完成提示。

#### Scenario: Rejected Only 中改评为合格
- **WHEN** 用户在 Rejected Only 模式下将当前照片改评为合格
- **THEN** 该照片从当前列表中移出，界面显示下一张糟糕照片

#### Scenario: Unrated Only 中完成最后一张
- **WHEN** 用户在 Unrated Only 模式下评价了最后一张未评价照片
- **THEN** 系统弹出全部评价完成提示

### Requirement: 切换模式时的定位
切换到 All Photos 时，系统 SHALL 停留在切换前正在查看的照片；切换到过滤模式时，系统 SHALL 从该模式列表的第一张开始。

#### Scenario: 回到 All Photos
- **WHEN** 用户在 Prized Only 模式下查看 `DSC00042` 时切换到 All Photos
- **THEN** All Photos 模式中显示的仍是 `DSC00042`

#### Scenario: 进入过滤模式
- **WHEN** 用户从 All Photos 切换到 Unrated Only
- **THEN** 显示未评价照片中的第一张
