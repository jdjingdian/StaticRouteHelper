## Why

路由规则的编辑、删除、分组分配功能在代码层面已实现，但入口仅通过右键菜单暴露，对用户严重不可发现——用户在正常使用流程中无法直观感知这些操作的存在，导致误认为功能缺失。需要在 `RouteListView` 的表格行中增加显式的行内操作入口，使核心 CRUD 操作触手可及。

## What Changes

- **路由表格新增"操作"列**：每行末尾显示行内按钮组（编辑、管理分组、删除），鼠标悬停时显示，或始终可见。
- **删除确认弹窗完善**：已有实现，保持不变；确认激活路由删除前会自动停用（已实现）。
- **右键菜单保留**：现有右键菜单作为进阶入口继续存在，不删除。
- **双击编辑保留**：现有双击行触发编辑，不删除。

## Capabilities

### New Capabilities

- `route-rule-inline-actions`: 路由列表行内操作按钮——在表格每行提供可见的编辑、管理分组、删除操作入口，无需依赖右键菜单即可完成完整 CRUD。

### Modified Capabilities

<!-- 无现有 spec 需要修改（现有 route-group-assign 仍适用，行为不变） -->

## Impact

- 仅影响 `StaticRouter/View/RouteListView.swift`：`routeTable` 中新增 `TableColumn`。
- `RouteEditSheet`、`AssignGroupsSheet`、`GroupSheets` 无需修改（已支持编辑模式）。
- 无模型层、服务层、特权助手变更。
