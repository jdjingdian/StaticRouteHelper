## MODIFIED Requirements

### Requirement: SwiftData ModelContainer 配置
应用启动时，当运行在 macOS 14.0 及以上版本时 SHALL 创建包含 `RouteRule` 和 `RouteGroup` 两个模型的 `ModelContainer`，并通过 `.modelContainer()` 修饰符注入到 SwiftUI 视图层级中。在 macOS 12–13 上 SHALL 改为初始化 `LegacyPersistenceStack`（Core Data）并通过 `.environment(\.managedObjectContext, context)` 注入，不初始化 SwiftData 栈。

#### Scenario: 应用首次启动（macOS 14+）
- **WHEN** 用户在 macOS 14+ 上首次启动应用（无历史数据）
- **THEN** 系统创建 SwiftData 存储文件，ModelContainer 成功初始化，应用正常显示空列表

#### Scenario: 应用正常启动（macOS 14+）
- **WHEN** 用户在 macOS 14+ 上启动应用（已有 SwiftData 数据）
- **THEN** ModelContainer 加载已有数据，视图通过 @Query 自动获取并显示路由规则和分组

#### Scenario: 应用在 macOS 12–13 上启动
- **WHEN** 用户在 macOS 12 或 13 上启动应用
- **THEN** 系统初始化 LegacyPersistenceStack，SwiftData 相关代码不执行，视图通过 @FetchRequest 加载路由规则

### Requirement: RouteRule 数据模型
系统 SHALL 提供 `RouteRule` @Model 类，在 macOS 14+ 作为 SwiftData 模型使用（行为不变）。在 macOS 12–13 上，数据由 Core Data `RouteRuleMO` 实体承担，`RouteRule` SwiftData 类仅在 macOS 14+ 环境中编译和使用。

`RouteRule` 在 macOS 14+ 上 SHALL 继续包含以下属性：
- `id: UUID`、`network: String`、`prefixLength: Int`、`gatewayType: GatewayType`、`gateway: String`、`isActive: Bool`、`groups: [RouteGroup]`、`createdAt: Date`

#### Scenario: 创建使用 IP 网关的路由规则（macOS 14+）
- **WHEN** 用户在 macOS 14+ 上创建路由规则，网络地址为 "10.0.0.0"，前缀长度为 8，网关类型为 `.ipAddress`，网关为 "192.168.1.1"
- **THEN** 系统保存 RouteRule 到 SwiftData，`subnetMask` 返回 "255.0.0.0"，`cidrNotation` 返回 "10.0.0.0/8"

#### Scenario: 创建使用网络接口的路由规则（macOS 14+）
- **WHEN** 用户在 macOS 14+ 上创建路由规则，网关类型为 `.interface`，网关为 "utun3"
- **THEN** 系统保存 RouteRule 到 SwiftData，`gateway` 值为 "utun3"

### Requirement: RouteGroup 数据模型
`RouteGroup` @Model 类仅在 macOS 14+ 上可用（行为不变）。在 macOS 12–13 上，分组功能不提供，`RouteGroup` 类不在 legacy 路径中编译使用。

#### Scenario: 创建路由分组（macOS 14+）
- **WHEN** 用户在 macOS 14+ 上创建名为 "Office VPN" 的分组
- **THEN** 系统保存 RouteGroup 到 SwiftData，`routes` 初始为空数组

### Requirement: 多对多关系管理
RouteRule 和 RouteGroup 之间的双向多对多关系 SHALL 仅在 macOS 14+ 上可用（行为不变）。在 macOS 12–13 上，`RouteRuleMO` 不包含 groups 关系，此需求不适用。

#### Scenario: 将路由添加到分组（macOS 14+）
- **WHEN** 在 macOS 14+ 上将一条 RouteRule 添加到 "Office VPN" 分组
- **THEN** 该 RouteRule 的 `groups` 数组包含 "Office VPN"，该分组的 `routes` 数组包含该 RouteRule

#### Scenario: 将同一路由添加到多个分组（macOS 14+）
- **WHEN** 在 macOS 14+ 上将 "192.168.4.0/24" 路由同时添加到 "Office VPN" 和 "Home VPN" 分组
- **THEN** 该路由的 `groups` 数组同时包含两个分组

#### Scenario: 从分组中移除路由（macOS 14+）
- **WHEN** 在 macOS 14+ 上从 "Office VPN" 分组中移除 "192.168.4.0/24" 路由
- **THEN** 该路由仍然存在于 SwiftData 中，`groups` 不再包含 "Office VPN"，但仍包含 "Home VPN"

### Requirement: Core Data 数据迁移
应用在 macOS 14+ 上首次以新版本启动时，SHALL 检测旧 Core Data 存储（DataModel / StaticRouteLegacy）是否存在。若存在，SHALL 读取其中数据，解析为路由规则列表，并导入到 SwiftData 中（所有导入的路由不关联任何 Group）。迁移完成后 SHALL 删除旧 Core Data 存储文件。此逻辑在 macOS 12–13 上不执行。

#### Scenario: 从旧版本升级且有数据（macOS 14+）
- **WHEN** 用户在 macOS 14+ 从旧版本升级，旧 Core Data 中存有 3 条路由规则
- **THEN** 系统自动将 3 条路由导入 SwiftData（isActive 均为 false，groups 为空），删除旧存储

#### Scenario: 从旧版本升级但无数据（macOS 14+）
- **WHEN** 用户在 macOS 14+ 从旧版本升级，Core Data 存储存在但为空
- **THEN** 系统跳过导入，删除旧存储

#### Scenario: 全新安装（macOS 14+）
- **WHEN** 用户在 macOS 14+ 上全新安装应用，不存在旧 Core Data 存储
- **THEN** 系统跳过迁移逻辑，正常初始化 SwiftData
