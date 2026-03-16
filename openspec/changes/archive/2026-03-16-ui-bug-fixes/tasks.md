## 1. SystemRouteTableView — 用户路由 SF Symbol 标记

- [x] 1.1 在 `SystemRouteTableView.swift` 的"目标"列中，将 `Circle().fill(Color.accentColor).frame(width: 6, height: 6)` 替换为 `Image(systemName: "person.fill").foregroundStyle(Color.accentColor).imageScale(.small)`

## 2. GroupSheets — AddGroupSheet 图标选择器布局修复

- [x] 2.1 在 `GroupSheets.swift` 中，将 `AddGroupSheet` 的 `LazyVGrid(columns: Array(repeating: .init(.fixed(40)), count: 7), spacing: 8)` 替换为 `HStack(spacing: 12)`，按钮 frame 改为 `width: 36, height: 36`，保持选中高亮逻辑不变

## 3. GroupSheets — 新增 AssignGroupsSheet

- [x] 3.1 在 `GroupSheets.swift` 中新增 `AssignGroupsSheet` 视图，接收 `rule: RouteRule`，通过 `@Query(sort: \RouteGroup.sortOrder)` 获取所有分组，使用 `@State private var selectedGroupIDs: Set<PersistentIdentifier>` 追踪勾选状态
- [x] 3.2 `AssignGroupsSheet` 初始化时将 `rule.groups.map(\.persistentModelID)` 装入 `selectedGroupIDs`
- [x] 3.3 `AssignGroupsSheet` body：若无分组显示提示文字"尚无分组，请先在侧栏创建分组"；否则用 `List` 显示分组列表，每行包含勾选图标（`checkmark` / 空）、分组图标（`Image(systemName:)`）、分组名称；底部"取消"和"保存"按钮
- [x] 3.4 实现 `save()` 方法：清除 `rule.groups` 所有关联，再遍历 `selectedGroupIDs` 将对应 `RouteGroup` 重新关联（同步更新 `RouteGroup.routes`），调用 `modelContext.save()`，调用 `dismiss()`

## 4. RouteListView — 右键菜单新增"管理分组"入口

- [x] 4.1 在 `RouteListView.swift` 中添加 `@State private var routeToAssignGroups: RouteRule? = nil`
- [x] 4.2 在 `contextMenu(forSelectionType:)` 的 `Button("编辑")` 和 `Button("删除")` 之间插入 `Button("管理分组…") { routeToAssignGroups = rule }`
- [x] 4.3 在 `RouteListView.body` 的 `.sheet` 链中添加 `.sheet(item: $routeToAssignGroups) { rule in AssignGroupsSheet(rule: rule) }`
