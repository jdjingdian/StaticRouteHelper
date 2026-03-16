## ADDED Requirements

### Requirement: SwiftData ModelContainer 配置
应用启动时 SHALL 创建包含 `RouteRule` 和 `RouteGroup` 两个模型的 `ModelContainer`，并通过 `.modelContainer()` 修饰符注入到 SwiftUI 视图层级中。

#### Scenario: 应用首次启动
- **WHEN** 用户首次启动应用（无历史数据）
- **THEN** 系统创建 SwiftData 存储文件，ModelContainer 成功初始化，应用正常显示空列表

#### Scenario: 应用正常启动
- **WHEN** 用户启动应用（已有 SwiftData 数据）
- **THEN** ModelContainer 加载已有数据，视图通过 @Query 自动获取并显示路由规则和分组

### Requirement: RouteRule 数据模型
系统 SHALL 提供 `RouteRule` @Model 类，包含以下属性：
- `id: UUID`（唯一标识）
- `network: String`（目标网络地址，如 "192.168.4.0"）
- `prefixLength: Int`（CIDR 前缀长度，如 24）
- `gatewayType: GatewayType`（枚举：`.ipAddress` 或 `.interface`）
- `gateway: String`（网关 IP 地址或网络接口名称）
- `isActive: Bool`（该路由是否已在系统路由表中生效）
- `groups: [RouteGroup]`（所属分组，多对多关系的反向引用）
- `createdAt: Date`（创建时间）

RouteRule SHALL 提供计算属性 `subnetMask: String`，根据 `prefixLength` 计算对应的子网掩码字符串（如 24 → "255.255.255.0"）。

RouteRule SHALL 提供计算属性 `cidrNotation: String`，返回 "network/prefixLength" 格式（如 "192.168.4.0/24"）。

#### Scenario: 创建使用 IP 网关的路由规则
- **WHEN** 用户创建路由规则，网络地址为 "10.0.0.0"，前缀长度为 8，网关类型为 `.ipAddress`，网关为 "192.168.1.1"
- **THEN** 系统保存 RouteRule，`subnetMask` 返回 "255.0.0.0"，`cidrNotation` 返回 "10.0.0.0/8"

#### Scenario: 创建使用网络接口的路由规则
- **WHEN** 用户创建路由规则，网关类型为 `.interface`，网关为 "utun3"
- **THEN** 系统保存 RouteRule，`gateway` 值为 "utun3"

### Requirement: RouteGroup 数据模型
系统 SHALL 提供 `RouteGroup` @Model 类，包含以下属性：
- `id: UUID`（唯一标识）
- `name: String`（分组名称）
- `iconName: String?`（可选的 SF Symbol 图标名称）
- `sortOrder: Int`（排序顺序）
- `createdAt: Date`（创建时间）
- `routes: [RouteRule]`（关联的路由规则，多对多关系）

#### Scenario: 创建路由分组
- **WHEN** 用户创建名为 "Office VPN" 的分组
- **THEN** 系统保存 RouteGroup，`routes` 初始为空数组

### Requirement: 多对多关系管理
RouteRule 和 RouteGroup 之间 SHALL 维护双向多对多关系。向 RouteGroup.routes 添加一个 RouteRule 时，该 RouteRule.groups SHALL 自动包含该 RouteGroup（反之亦然）。

#### Scenario: 将路由添加到分组
- **WHEN** 将一条 RouteRule 添加到 "Office VPN" 分组
- **THEN** 该 RouteRule 的 `groups` 数组包含 "Office VPN"，该分组的 `routes` 数组包含该 RouteRule

#### Scenario: 将同一路由添加到多个分组
- **WHEN** 将 "192.168.4.0/24" 路由同时添加到 "Office VPN" 和 "Home VPN" 分组
- **THEN** 该路由的 `groups` 数组同时包含两个分组

#### Scenario: 从分组中移除路由
- **WHEN** 从 "Office VPN" 分组中移除 "192.168.4.0/24" 路由
- **THEN** 该路由仍然存在于 SwiftData 中，`groups` 不再包含 "Office VPN"，但仍包含 "Home VPN"

### Requirement: Core Data 数据迁移
应用首次以新版本启动时，SHALL 检测旧 Core Data 存储（DataModel）是否存在。若存在，SHALL 读取其中的 JSON blob 数据，解析为路由规则列表，并导入到 SwiftData 中（所有导入的路由不关联任何 Group）。迁移完成后 SHALL 删除旧 Core Data 存储文件。

#### Scenario: 从旧版本升级且有数据
- **WHEN** 用户从旧版本升级，Core Data 中存有 3 条路由规则
- **THEN** 系统自动将 3 条路由导入 SwiftData（isActive 均为 false，groups 为空），删除旧存储

#### Scenario: 从旧版本升级但无数据
- **WHEN** 用户从旧版本升级，Core Data 存储存在但为空
- **THEN** 系统跳过导入，删除旧存储

#### Scenario: 全新安装
- **WHEN** 用户全新安装应用，不存在旧 Core Data 存储
- **THEN** 系统跳过迁移逻辑，正常初始化 SwiftData
