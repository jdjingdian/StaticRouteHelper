## ADDED Requirements

### Requirement: macOS 12–13 路由规则 CRUD（基于 Core Data）
在 macOS 12–13 上，用户 SHALL 能够执行完整的路由规则增删改查操作，数据由 Core Data（`RouteRuleMO`）持久化：
- **添加路由**：通过路由编辑 Sheet 输入路由信息并保存到 Core Data。
- **编辑路由**：通过双击或上下文菜单打开编辑 Sheet，预填充现有数据，保存变更。
- **删除路由**：通过上下文菜单或 Delete 键删除，需确认；若路由已激活，先通过 Helper 撤销。
- **切换激活状态**：通过 Toggle 开关激活或停用路由（调用 Helper XPC）。

#### Scenario: 在 macOS 13 上添加路由规则
- **WHEN** 用户在 macOS 13 上点击"添加路由"，填写网络地址 "10.8.0.0"，前缀 24，IP 网关 "192.168.1.1"，点击"保存"
- **THEN** 系统创建 `RouteRuleMO` 实体并保存到 Core Data，路由列表中立即显示该条目

#### Scenario: 在 macOS 12 上编辑已有路由
- **WHEN** 用户在 macOS 12 上双击某条路由，修改网关地址，点击"保存"
- **THEN** 对应 `RouteRuleMO` 实体更新，若路由当前已激活，系统先撤销旧路由再激活新路由

#### Scenario: 在 macOS 13 上删除已激活路由
- **WHEN** 用户在 macOS 13 上右键已激活路由，选择"删除"并确认
- **THEN** 系统先通过 Helper XPC 从系统路由表删除该路由，再从 Core Data 中删除 `RouteRuleMO`

#### Scenario: 切换路由激活状态（macOS 12–13）
- **WHEN** 用户在 macOS 12–13 上点击路由行的 Toggle 开关
- **THEN** 系统通过 XPC 向 Helper 发送激活/停用指令，成功后更新 `RouteRuleMO.isActive` 并保存

### Requirement: macOS 12–13 路由列表视图（基于 @FetchRequest）
在 macOS 12–13 上，路由列表视图 SHALL 使用 `@FetchRequest` 驱动数据显示，功能上等价于 macOS 14+ 的 `@Query` 视图：
- 按 `createdAt` 升序排列显示所有 `RouteRuleMO`。
- 每行显示目标网络（CIDR 格式）、网关类型、激活状态 Toggle。
- **不显示分组标签列**（分组功能仅限 macOS 14+）。

#### Scenario: 列表自动刷新
- **WHEN** 用户在 macOS 13 上添加或删除路由
- **THEN** 路由列表视图无需手动刷新，`@FetchRequest` 自动响应 Core Data 变更并更新列表

### Requirement: 路由编辑 Sheet 在 macOS 12–13 隐藏分组相关 UI
在 macOS 12–13 上，路由编辑 Sheet SHALL 隐藏分组多选列表（`所属分组` 区域），其余字段（网络地址、前缀长度、网关类型、网关地址/接口名称）保持可用。

#### Scenario: 在 macOS 13 上打开添加路由 Sheet
- **WHEN** 用户在 macOS 13 上点击"添加路由"按钮
- **THEN** Sheet 显示网络地址、前缀长度、网关类型、网关/接口输入字段，不显示分组多选区域

### Requirement: 输入验证在 macOS 12–13 功能不变
路由编辑 Sheet 的输入验证逻辑（`RouteValidator`）是纯函数，不依赖 SwiftData。该验证逻辑 SHALL 在 macOS 12–13 上完整保留，行为与 macOS 14+ 一致。

#### Scenario: 在 macOS 12 上输入无效 IP 地址
- **WHEN** 用户在 macOS 12 上输入网络地址 "999.0.0.1"
- **THEN** 字段显示红色边框，保存按钮禁用，行为与 macOS 14+ 一致
