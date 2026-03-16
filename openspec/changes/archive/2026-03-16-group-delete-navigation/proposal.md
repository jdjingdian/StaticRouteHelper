## Why

删除分组后，若被删除的分组正是当前侧栏选中项，`SidebarView` 的 `selection` 绑定仍保留对已删除分组的引用，导致主内容区持续显示该分组的路由列表，UI 出现残留，用户需要手动点击其他条目才能恢复正常。应在删除操作完成后立即将导航状态重置到安全位置。

## What Changes

- **当前分组被删除时**：删除后自动将 `selection` 切换到 `.allRoutes`，确保内容区不残留已删除分组的视图。
- **非当前分组被删除时**：`selection` 保持不变，用户停留在当前分组，无感知切换。
- 删除逻辑本身（解除路由关联、`modelContext.delete`、`save`）不变。

## Capabilities

### New Capabilities

- `group-delete-navigation`: 分组删除后的导航重置——若删除的是当前选中分组，则跳转至"所有路由"；否则保持当前选中项不变。

### Modified Capabilities

<!-- 无现有 spec 需要变更 -->

## Impact

- 仅影响 `StaticRouter/View/SidebarView.swift`：`deleteGroup(_:)` 方法 + `SidebarView` 需要访问 `selection` 绑定。
- 无模型层、服务层、特权助手变更。
