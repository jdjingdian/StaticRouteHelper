## Context

本次修复针对 `ui-redesign` 变更完成后残留的三个 UI 缺陷：

1. **SystemRouteTableView 用户路由标记**：当前用 6×6 px 的 `Circle()` 实心圆点标记用户添加的路由，过小且不醒目，用户容易忽略。
2. **AddGroupSheet 布局破损**：图标选择器使用 `LazyVGrid(columns: Array(repeating: .init(.fixed(40)), count: 7))`，7列 × 40pt = 280pt，加上 padding(20) × 2 = 320pt，恰好撑满 sheet 宽度但无余量，导致在某些情况下溢出或截断，且列数与图标数（7个）恰好相等，`LazyVGrid` 无法灵活换行。
3. **现有路由分组分配入口**：用户需要双击或右键"编辑"才能进入完整的 `RouteEditSheet` 来更改分组，但表单较长且包含网络配置，操作路径较深。

技术栈：SwiftUI + SwiftData，macOS 15+，非沙盒应用。

## Goals / Non-Goals

**Goals:**
- 将用户路由标记升级为 SF Symbol（`person.fill`），保持当前行背景高亮逻辑不变
- 修复 `AddGroupSheet` 图标选择器布局，改为 `HStack` + `ForEach` 流式排列，宽度自适应
- 新增 `AssignGroupsSheet`：专用分组分配弹窗，通过右键菜单"管理分组…"触发，展示所有分组的复选框，保存时更新 `RouteRule.groups` 双向关联

**Non-Goals:**
- 不修改路由激活逻辑
- 不修改 `RouteEditSheet` 中现有的分组多选 UI
- 不修改 `RouteHelper` 特权助手
- 不改动数据模型（`RouteRule`、`RouteGroup`）

## Decisions

### D1：用户路由标记使用 `person.fill` 图标

**选择**：`Image(systemName: "person.fill")` 替换 `Circle()`，使用 `.accentColor` 着色，`.imageScale(.small)`。

**原因**：`person.fill` 语义清晰（用户添加的），比圆点更大、更易识别，且符合 macOS HIG 对 SF Symbol 的使用规范。其他候选（`star.fill`、`checkmark.seal.fill`）语义较模糊。

### D2：AddGroupSheet 图标选择器改用 HStack 固定间距

**选择**：移除 `LazyVGrid`，改为 `HStack(spacing: 12)` + `ForEach`，图标按钮统一 36×36pt。

**原因**：当前 7 个图标 + 固定列宽布局在 320pt sheet 中已满载，扩展图标时会溢出。`HStack` 对当前 7 个图标足够，且更简单、无需计算列数；若未来图标超过 8-9 个可改为 `FlowLayout` 或 `LazyVGrid` 自适应列。

### D3：AssignGroupsSheet 作为独立 Sheet，不复用 RouteEditSheet

**选择**：新建 `AssignGroupsSheet` 视图，接收 `RouteRule` 和所有 `RouteGroup`，展示勾选列表，保存时写入 `RouteRule.groups` 和反向 `RouteGroup.routes`。

**原因**：`RouteEditSheet` 包含网络地址、网关等字段，复用它只为改分组会让 UX 显得过重。专用弹窗更轻量、更聚焦，且不会意外触发路由重新激活逻辑（编辑已激活路由会触发 deactivate + activate）。

**双向关联维护**：SwiftData 中 `RouteRule.groups` 和 `RouteGroup.routes` 是手动维护的双向关系。保存时需同时更新两侧。

## Risks / Trade-offs

- **[风险] AssignGroupsSheet 保存时双向关联不一致** → 缓解：保存前先清除所有旧关联，再按选中状态重建，确保幂等。
- **[Trade-off] HStack 超出图标时不换行** → 目前仅 7 个图标，HStack 足够；若产品后续需要更多图标，需换回 LazyVGrid 自适应列（`GridItem(.adaptive(minimum: 36))`）。
- **[风险] Table contextMenu 与选中行的关联** → `RouteListView` 已使用 `contextMenu(forSelectionType:)` API，新增菜单项只需追加 `Button`，无额外风险。
