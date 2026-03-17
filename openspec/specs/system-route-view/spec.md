## MODIFIED Requirements

### Requirement: 系统路由表展示
当用户选中 Sidebar 中的 "Route Table" 时，Detail 区域 SHALL 显示当前系统路由表的完整内容，以表格形式呈现（Destination、Gateway、Flags、Interface、Expire）。此功能在 macOS 12+ 上均可用；SwiftUI `Table` 视图在 macOS 12 上已支持，无需额外适配。

如果视图中存在 macOS 14+ 专属的 SwiftUI API（如类型化 `@Environment` 注入），SHALL 在 macOS 12–13 路径上替换为等效的 `@EnvironmentObject` 方式。

#### Scenario: 查看系统路由表（所有版本）
- **WHEN** 用户在任意支持版本（macOS 12+）上点击 Sidebar 中的 "Route Table"
- **THEN** 系统读取内核路由表数据，解析并以表格形式显示，包含 Destination、Gateway、Flags、Interface、Expire 列

### Requirement: 用户路由标记
系统路由表视图 SHALL 将路由条目分组显示。在 macOS 14+ 上，"My Routes" section 与 SwiftData 中的 `RouteRule` 匹配。在 macOS 12–13 上，匹配来源改为 Core Data 中的 `RouteRuleMO`，行为等价。

#### Scenario: 系统路由表包含用户添加的路由（macOS 14+）
- **WHEN** 用户在 macOS 14+ 上已激活 "192.168.4.0/24 → utun3" 路由，查看系统路由表
- **THEN** 该条目显示在 "My Routes" section 中，带有浅色高亮背景

#### Scenario: 系统路由表包含用户添加的路由（macOS 12–13）
- **WHEN** 用户在 macOS 13 上已激活 "192.168.4.0/24 → utun3" 路由（isActive 为 true 的 RouteRuleMO），查看系统路由表
- **THEN** 该条目显示在 "My Routes" section 中，带有浅色高亮背景

#### Scenario: 系统路由表中无用户路由
- **WHEN** 用户未激活任何路由，查看系统路由表
- **THEN** "My Routes" section 为空或不显示，所有条目显示在 "System Routes" section

### Requirement: 系统路由表搜索和过滤
搜索过滤功能不依赖 SwiftData，SHALL 在 macOS 12+ 上完整可用，行为不变。

#### Scenario: 搜索路由条目（所有版本）
- **WHEN** 用户在任意支持版本上在搜索栏输入 "192.168"
- **THEN** 表格仅显示 Destination 或 Gateway 包含 "192.168" 的条目

#### Scenario: 清空搜索
- **WHEN** 用户清空搜索栏
- **THEN** 表格恢复显示所有条目

### Requirement: 系统路由表刷新
刷新功能不依赖 SwiftData，SHALL 在 macOS 12+ 上完整可用，行为不变。

#### Scenario: 手动刷新路由表（所有版本）
- **WHEN** 用户在任意支持版本上点击刷新按钮
- **THEN** 系统重新读取内核路由表，更新表格内容和最后刷新时间

#### Scenario: 首次进入路由表视图
- **WHEN** 用户首次点击 Sidebar 中的 "Route Table"
- **THEN** 系统自动获取并显示路由表，底部显示 "共 N 条路由 · 刚刚刷新"
