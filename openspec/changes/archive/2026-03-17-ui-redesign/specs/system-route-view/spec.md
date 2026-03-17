## ADDED Requirements

### Requirement: 系统路由表展示
当用户选中 Sidebar 中的 "Route Table" 时，Detail 区域 SHALL 显示当前系统路由表的完整内容，以表格形式呈现，列包含：
- Destination（目标地址）
- Gateway（网关）
- Flags（标志位）
- Interface（网络接口）
- Expire（过期时间）

#### Scenario: 查看系统路由表
- **WHEN** 用户点击 Sidebar 中的 "Route Table"
- **THEN** 系统通过 Helper 执行 `netstat -nr -f inet` 获取路由表数据，解析并以表格形式显示

### Requirement: 用户路由标记
系统路由表视图 SHALL 将路由条目分为两组显示：
1. "My Routes" Section：与 SwiftData 中的 RouteRule 匹配的条目，使用浅色 Accent Color 背景高亮
2. "System Routes" Section：其余系统路由条目

匹配逻辑 SHALL 基于 destination 网段和 gateway/interface 的比对。

#### Scenario: 系统路由表包含用户添加的路由
- **WHEN** 用户已激活 "192.168.4.0/24 → utun3" 路由，查看系统路由表
- **THEN** 该条目显示在 "My Routes" section 中，带有浅色高亮背景

#### Scenario: 系统路由表中无用户路由
- **WHEN** 用户未激活任何路由，查看系统路由表
- **THEN** "My Routes" section 为空或不显示，所有条目显示在 "System Routes" section

### Requirement: 系统路由表搜索和过滤
系统路由表视图 SHALL 提供搜索栏，支持按 Destination、Gateway 或 Interface 进行文本搜索过滤。

#### Scenario: 搜索路由条目
- **WHEN** 用户在搜索栏输入 "192.168"
- **THEN** 表格仅显示 Destination 或 Gateway 包含 "192.168" 的条目

#### Scenario: 清空搜索
- **WHEN** 用户清空搜索栏
- **THEN** 表格恢复显示所有条目

### Requirement: 系统路由表刷新
系统路由表视图 SHALL 提供手动刷新按钮。点击刷新 SHALL 重新获取系统路由表数据。视图底部 SHALL 显示路由总数和最后刷新时间。

#### Scenario: 手动刷新路由表
- **WHEN** 用户点击刷新按钮
- **THEN** 系统重新执行 `netstat -nr -f inet`，更新表格内容和最后刷新时间

#### Scenario: 首次进入路由表视图
- **WHEN** 用户首次点击 Sidebar 中的 "Route Table"
- **THEN** 系统自动获取并显示路由表，底部显示 "共 N 条路由 · 刚刚刷新"
