## Why

`ui-redesign` 完成后发现三处 UI 缺陷影响可用性：用户路由标记不明显、分组分配入口不够显眼、`AddGroupSheet` 图标选择器布局破损。这些问题需要在发布前修复。

## What Changes

- **用户路由标记**：`SystemRouteTableView` 中将 6×6 小圆点（`Circle()`）替换为 SF Symbol 图标（`person.fill`），使用户添加的路由在系统路由表中更易识别。
- **分组分配入口**：`RouteListView` 右键菜单新增"管理分组…"选项，直接打开一个专用的分组多选弹窗，让用户无需进入完整编辑表单即可快速为现有路由分配/取消分组。
- **AddGroupSheet 布局修复**：将 `LazyVGrid` 固定列宽图标选择器替换为 `HStack` + `Spacer` 自适应布局，确保在 320pt 宽度的 Sheet 中正确显示，避免溢出或截断。

## Capabilities

### New Capabilities

- `route-group-assign`: 专用分组分配弹窗（`AssignGroupsSheet`），允许对已存在路由进行多选分组管理，独立于路由编辑表单。

### Modified Capabilities

（无 spec 层级行为变更）

## Impact

- `StaticRouter/View/SystemRouteTableView.swift` — 修改用户路由标记图标
- `StaticRouter/View/GroupSheets.swift` — 修复 `AddGroupSheet` 图标选择器布局，新增 `AssignGroupsSheet`
- `StaticRouter/View/RouteListView.swift` — 在右键菜单添加"管理分组…"入口
