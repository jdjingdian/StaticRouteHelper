## ADDED Requirements

### Requirement: 双持久化栈按 OS 版本条件初始化
应用启动时 SHALL 根据当前 macOS 版本选择持久化后端：
- macOS 14.0 及以上：初始化 SwiftData `ModelContainer`（现有行为不变）。
- macOS 12.0–13.x：初始化 Core Data `NSPersistentContainer`，实体为 `RouteRuleMO`。

两条路径 SHALL 在 `StaticRouteHelperApp.swift` 的 `@main` 入口通过 `if #available(macOS 14, *)` 分支选择，互不干扰。

#### Scenario: 在 macOS 14+ 上启动
- **WHEN** 应用在 macOS 14.0 或更高版本上启动
- **THEN** 系统初始化 SwiftData ModelContainer，通过 `.modelContainer()` 注入视图层级，Core Data 栈不初始化

#### Scenario: 在 macOS 12–13 上启动
- **WHEN** 应用在 macOS 12.0 或 13.x 上启动
- **THEN** 系统初始化 `LegacyPersistenceStack`（NSPersistentContainer），通过 `.environment(\.managedObjectContext, context)` 注入视图层级，SwiftData 栈不初始化

### Requirement: LegacyPersistenceStack 提供 Core Data 栈
系统 SHALL 提供 `LegacyPersistenceStack` 类（`NSObject` 子类），封装 macOS 12–13 的 Core Data 持久化栈：
- 内部持有 `NSPersistentContainer`，模型名称为 `StaticRouteLegacy`。
- 对外暴露 `viewContext: NSManagedObjectContext`。
- 首次初始化时 SHALL 自动加载持久化存储（`loadPersistentStores`），失败时记录错误日志但不崩溃。

#### Scenario: 首次在 macOS 13 上启动（无历史数据）
- **WHEN** 应用首次在 macOS 13 上启动，无已有 Core Data 存储文件
- **THEN** `LegacyPersistenceStack` 创建新的 SQLite 存储文件，`viewContext` 可用，应用显示空列表

#### Scenario: 再次在 macOS 13 上启动（有历史数据）
- **WHEN** 应用在 macOS 13 上再次启动，已有 Core Data 存储文件
- **THEN** `LegacyPersistenceStack` 加载已有存储，`viewContext` 包含已保存的 `RouteRuleMO` 实体

### Requirement: RouteRuleMO 实体定义
系统 SHALL 在 `StaticRouteLegacy.xcdatamodeld` 中定义 `RouteRuleMO` 实体，对应以下属性（与 SwiftData `RouteRule` 字段保持一致）：
- `id: UUID`（必填）
- `network: String`（必填）
- `prefixLength: Int16`（必填）
- `gatewayType: String`（枚举原始值，必填）
- `gateway: String`（必填）
- `isActive: Bool`（必填，默认 false）
- `note: String?`（可选）
- `createdAt: Date`（必填）

`RouteRuleMO` SHALL 不包含 `groups` 关系（分组功能仅限 macOS 14+）。

#### Scenario: 保存一条路由规则到 Core Data
- **WHEN** 用户在 macOS 13 上通过 Legacy 路由编辑 Sheet 保存一条新路由
- **THEN** 系统在 `viewContext` 中插入 `RouteRuleMO` 实体并调用 `save()`，数据持久化到磁盘

### Requirement: OS 升级后自动迁移 Core Data → SwiftData
当应用在 macOS 14+ 上首次启动时，SHALL 检测是否存在 `LegacyPersistenceStack` 使用的 Core Data 存储文件。若存在：
1. 读取所有 `RouteRuleMO` 实体。
2. 将其转换为 SwiftData `RouteRule` 实体（`isActive` 均置为 false，`groups` 为空）并插入 `ModelContext`。
3. 保存 SwiftData 上下文。
4. 删除 Core Data 存储文件（迁移幂等保障）。

此逻辑 SHALL 与现有 `CoreDataMigrator`（旧版 Core Data → SwiftData 迁移）并列执行，不互相干扰。

#### Scenario: 从 macOS 13 升级到 macOS 14，有 Legacy Core Data 数据
- **WHEN** 用户升级 macOS 后首次在 macOS 14 上启动应用，Legacy Core Data 中有 5 条路由
- **THEN** 系统将 5 条路由导入 SwiftData（isActive 均为 false），删除 Legacy Core Data 存储，应用正常显示 5 条路由

#### Scenario: 在 macOS 14 上全新安装（无 Legacy 数据）
- **WHEN** 用户在 macOS 14 上全新安装，不存在 Legacy Core Data 存储
- **THEN** 系统跳过 Legacy 迁移逻辑，正常初始化 SwiftData
