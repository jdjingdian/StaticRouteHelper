## Context

`SystemRouteTableView` 当前将全部系统路由（通常 100~200+ 条）渲染在一张 `Table` 中，本应用添加的路由已通过 `isUserRoute(_:)` 标记（蓝色人形图标 + 背景色），但条目仍混在大量系统原生路由中。用户需要向下滚动或使用搜索才能找到自己关心的条目。

代码中已存在 `myRoutes`（本应用路由）和 `systemOnlyRoutes`（系统原生路由）两个计算属性，但当前视图只使用 `filteredRoutes`（全量），这两个属性尚未被利用。

## Goals / Non-Goals

**Goals:**
- 在系统路由表工具栏新增"仅显示我的路由"切换按钮（toggle）
- 启用时隐藏所有非本应用的系统路由，仅显示 `myRoutes`
- 关闭时恢复显示全量路由（`filteredRoutes`）
- 切换状态在视图生命周期内保持（`@State`，无需跨启动持久化）
- 搜索与折叠过滤可组合使用（先折叠再搜索，或反之）

**Non-Goals:**
- 持久化用户偏好（UserDefaults / SwiftData）
- 对"系统路由"进行分类折叠（按协议/接口分组展开）
- 修改路由表数据源或 `RouterService`

## Decisions

**D1：使用布尔 `@State` 切换，而非 DisclosureGroup**

选择工具栏 Toggle 而非 `DisclosureGroup` 折叠行，因为用户意图是"聚焦我的路由"而非"折叠某一类别"。Toggle 语义更清晰，操作路径更短（一次点击 vs. 两次展开/收起）。

备选：`DisclosureGroup` 将系统路由包裹为可折叠区域——缺点是 `Table` 不支持原生分组折叠，需要两张独立 `List`/`Table`，结构变化大，且列头无法复用。

**D2：复用现有 `myRoutes` 和 `filteredRoutes` 计算属性**

`routeTable` 的数据源从 `filteredRoutes` 改为根据 `showOnlyMyRoutes` 条件选择 `myRoutes` 或 `filteredRoutes`，避免引入新的计算路径，逻辑最小化。

**D3：切换 UI 选用 `Toggle` + `Label`，放置在工具栏 HStack 刷新按钮左侧**

与刷新按钮同区域，视觉上属于"路由表控制"分组。使用 `.toggleStyle(.button)` 使其以按钮形态呈现，激活时有选中态，符合 macOS 惯例（类似 Finder 显示/隐藏侧边栏按钮）。

## Risks / Trade-offs

- [状态不持久] 用户每次进入路由表视图需重新切换 → 可接受，属于轻量过滤，不是用户设置；若后续需持久化可升级为 `@AppStorage`。
- [空状态] 若本应用无激活路由且用户启用过滤，表格为空 → 需显示空状态提示，避免用户误以为数据加载失败。
- [搜索组合] 过滤后再搜索，结果可能为空 → 空状态文案需区分"无我的路由"和"搜索无结果"两种情形。
