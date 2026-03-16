## Context

`RouteListView` 使用 SwiftUI `Table` 渲染路由规则列表。现有的编辑/删除/分组管理入口仅通过 `.contextMenu(forSelectionType:)` 和 `primaryAction`（双击）暴露，这两个交互模式在 macOS 上对非技术用户可发现性极低。

现有状态机（`@State private var routeToEdit/routeToDelete/routeToAssignGroups`）和对应 `.sheet`/`.alert` 呈现逻辑已完整，无需修改——只需增加新的触发入口。

`RouteEditSheet` 已支持 `existingRule` 编辑模式，`AssignGroupsSheet` 已实现分组管理，`performDelete` 已处理激活路由自动停用。

## Goals / Non-Goals

**Goals:**
- 在路由表格中为每行添加可见的行内操作按钮（编辑、管理分组、删除）。
- 操作按钮触发现有的 sheet/alert 状态，不引入新的状态管理。
- 保持现有右键菜单和双击编辑入口不变。

**Non-Goals:**
- 不修改 `RouteEditSheet`、`AssignGroupsSheet` 的逻辑。
- 不添加批量操作（多选删除/编辑）。
- 不修改模型层或服务层。

## Decisions

**Decision 1: 新增 `TableColumn("操作")` 渲染行内按钮**

SwiftUI `Table` 支持自定义列，每行可渲染任意视图。在"激活"列之后新增一列，包含三个 `Button`（SF Symbol）：
- `pencil`（编辑）→ `routeToEdit = rule`
- `folder.badge.person.crop`（管理分组）→ `routeToAssignGroups = rule`
- `trash`（删除）→ `routeToDelete = rule`

按钮使用 `.buttonStyle(.plain)` + `.foregroundStyle(.secondary)` 与表格风格一致。

*备选方案 A*：在行上用 `onHover` 切换按钮可见性——实现复杂，`Table` 不直接支持行级 hover state。  
*备选方案 B*：工具栏按钮（依赖行选中状态）——需先点击选中再点工具栏，步骤更多，不如行内直接。  
选择 `TableColumn` 方案最简单，与现有 `Table` 结构一致。

**Decision 2: 固定列宽，按钮始终可见**

不做 hover 显隐——macOS `Table` 行级 hover 实现复杂且不稳定。按钮始终显示，使用小尺寸 `.imageScale(.small)` 降低视觉噪音。列宽固定约 90pt（三个按钮 + 间距）。

**Decision 3: 删除按钮使用 `.foregroundStyle(.red)` / `role: .destructive` 颜色区分**

删除是破坏性操作，使用红色图标提升视觉警示。编辑和分组管理使用 `.secondary` 颜色。

## Risks / Trade-offs

- [Risk] 操作列占据固定宽度，在窗口较窄时可能压缩其他列。→ 固定列宽 `.width(90)` 并给其他列设置合理的最小宽度。
- [Risk] `Table` 行中的 `Button` 点击有时会同时触发行选中和操作。→ macOS `Table` 中 `Button` 点击不会触发 `primaryAction`，行为符合预期。
