## Why

系统路由表中存在大量由操作系统或其他程序自动生成的路由条目（如组播地址、链路本地等），导致用户难以快速定位本应用所添加的已激活路由。虽然搜索功能可以过滤，但需要额外操作步骤；提供折叠/展开功能可让用户一键聚焦关键条目，显著提升可读性。

## What Changes

- 在系统路由表视图顶部或工具栏区域新增"折叠系统路由"切换按钮（或开关）
- 当折叠模式启用时，仅显示由本应用添加的路由条目（即在 `RouteRule` 数据库中存在对应记录且 `isActive == true` 的路由）
- 当折叠模式关闭时，显示全部 191+ 条系统路由（当前默认行为）
- 折叠状态在视图会话内保持（无需持久化跨启动）

## Capabilities

### New Capabilities

- `system-route-filter`: 系统路由表支持"仅显示本应用路由"过滤模式，通过切换按钮控制显示范围，非激活的系统原生条目可被隐藏

### Modified Capabilities

（无，现有 spec 无行为层面变化）

## Impact

- `StaticRouter/View/SystemRouteTableView.swift`：新增过滤状态和切换 UI
- `StaticRouter/Services/RouterService.swift`（只读）：需要读取当前激活路由的目标地址，用于匹配系统路由表中的条目
- `StaticRouter/Model/RouteRule.swift`（只读）：用于获取本应用路由的 `destination` 集合
