## 0. Bug 修复 — Table selection 绑定缺失

- [x] 0.1 在 `RouteListView` 新增 `@State private var tableSelection: Set<UUID> = []`（与 `RouteRule.id: UUID` 类型匹配）
- [x] 0.2 将 `Table(routes)` 改为 `Table(routes, selection: $tableSelection)`，使右键菜单 `contextMenu(forSelectionType:)` 和双击 `primaryAction` 能正确接收选中行

## 1. RouteListView — 新增行内操作列

- [x] 1.1 在 `routeTable` 的 `Table` 中，紧接"激活"列之后新增 `TableColumn("操作")` 列，设置固定宽度 `.width(90)`
- [x] 1.2 在操作列的 cell 内实现三个 `Button`：编辑（`pencil`）、管理分组（`person.crop.rectangle.stack` 或 `folder.badge.person.crop`）、删除（`trash`），使用 HStack 横向排列
- [x] 1.3 编辑按钮点击时设置 `routeToEdit = rule`；管理分组按钮设置 `routeToAssignGroups = rule`；删除按钮设置 `routeToDelete = rule`
- [x] 1.4 删除按钮使用 `.foregroundStyle(.red)` 区分破坏性操作；编辑和分组管理使用 `.foregroundStyle(.secondary)`
- [x] 1.5 所有按钮使用 `.buttonStyle(.plain)` 和 `.imageScale(.small)` 保持与表格风格一致

## 2. 验证

- [x] 2.1 运行 App，确认路由表格每行末尾显示三个操作按钮（铅笔、文件夹、垃圾桶）
- [x] 2.2 点击编辑按钮 → 确认弹出 RouteEditSheet 并预填充该路由数据
- [x] 2.3 点击管理分组按钮 → 确认弹出 AssignGroupsSheet 并预勾选当前分组
- [x] 2.4 点击删除按钮 → 确认弹出确认弹窗，激活路由显示停用提示，非激活显示"无法撤销"
- [x] 2.5 确认右键菜单和双击编辑仍正常工作，与行内按钮行为一致
