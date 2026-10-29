# photo-deletion Specification

## Purpose

定义如何在用户确认后批量删除被评价为糟糕的照片，确保同一张照片的 RAW 与输出文件一起处理，且不会误删合格或未评价的照片。

## Requirements

### Requirement: 删除前必须确认
系统 SHALL 只在用户明确确认后删除照片。确认提示 SHALL 展示合格与糟糕的数量，存在未评价照片时还 SHALL 展示未评价数量。确认提示 SHALL 可通过两种方式出现：全部评价完成时自动出现，或用户在已加载文件夹且存在糟糕照片时随时通过菜单触发。

#### Scenario: 手动触发
- **WHEN** 文件夹中仍有未评价照片，且至少有一张糟糕照片，用户通过菜单触发删除
- **THEN** 系统弹出确认提示，展示合格、糟糕与未评价的数量

#### Scenario: 没有糟糕照片
- **WHEN** 已加载的文件夹中没有糟糕照片
- **THEN** 菜单中的删除操作不可用

#### Scenario: 取消删除
- **WHEN** 用户在确认提示中选择取消
- **THEN** 不删除任何文件，评价保持不变

### Requirement: 删除范围
用户确认后，系统 SHALL 将每张糟糕照片的全部关联文件（RAW 与输出文件）从照片文件夹中删除。合格与未评价照片的文件 SHALL NOT 受到影响。

#### Scenario: RAW 与输出文件一起删除
- **WHEN** 糟糕照片 `DSC00001` 有 `.ARW` 与 `.HIF` 两个文件，用户确认删除
- **THEN** 两个文件都被删除

#### Scenario: 不影响其他照片
- **WHEN** 用户确认删除
- **THEN** 所有合格与未评价照片的文件保持不变

### Requirement: 部分失败时继续并汇报
单个文件删除失败时，系统 SHALL 继续处理其余文件。完成后系统 SHALL 汇报成功删除的文件数，并列出每个失败文件的名称与原因。

#### Scenario: 某个文件无法删除
- **WHEN** 删除过程中有一个文件因权限不足而失败
- **THEN** 其余文件照常删除，结果中列出该失败文件及原因

### Requirement: 删除后的状态
删除完成后，被删除的糟糕照片 SHALL 从照片列表中移除，其已存评价 SHALL 一并清除。如果删除时处于 Rejected Only 模式，系统 SHALL 回到 All Photos 模式。

#### Scenario: 列表更新
- **WHEN** 删除完成
- **THEN** 照片列表与进度只包含剩余照片

#### Scenario: 从 Rejected Only 模式删除
- **WHEN** 用户在 Rejected Only 模式下确认删除
- **THEN** 删除完成后切换到 All Photos 模式
