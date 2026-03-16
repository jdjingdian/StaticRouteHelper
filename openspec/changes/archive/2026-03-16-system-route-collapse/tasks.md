## 1. 状态与过滤逻辑

- [x] 1.1 在 `SystemRouteTableView` 新增 `@State private var showOnlyMyRoutes: Bool = false`
- [x] 1.2 新增计算属性 `displayedRoutes`：当 `showOnlyMyRoutes` 为 `true` 时返回 `myRoutes`，否则返回 `filteredRoutes`
- [x] 1.3 将 `routeTable` 的数据源从 `filteredRoutes` 改为 `displayedRoutes`

## 2. 工具栏切换 UI

- [x] 2.1 在工具栏 `HStack` 刷新按钮左侧新增 `Toggle` 控件，绑定 `$showOnlyMyRoutes`
- [x] 2.2 使用 `.toggleStyle(.button)` 使其以按钮形态呈现，`label` 使用 `Label("仅我的路由", systemImage: "person.fill")`
- [x] 2.3 为切换按钮添加 `.help("仅显示本应用添加的路由")` tooltip

## 3. 空状态处理

- [x] 3.1 在 `routeTable` 视图中，当 `displayedRoutes` 为空且路由表非空时，显示空状态视图（`ContentUnavailableView` 或自定义 `VStack`）
- [x] 3.2 空状态文案：若 `showOnlyMyRoutes == true` 且 `searchText` 为空，提示"当前没有本应用添加的路由"；若同时有搜索词，提示"未找到匹配的我的路由"

## 4. 状态栏计数更新

- [x] 4.1 状态栏条数文案在过滤模式下显示"共 X 条我的路由（共 Y 条系统路由）"，关闭过滤时保持原有"共 Y 条路由"格式
