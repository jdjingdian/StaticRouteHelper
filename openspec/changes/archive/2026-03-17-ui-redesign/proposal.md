## Why

当前应用的 UI 处于新旧交替的半成品状态：新 UI（`MainWindow`）仅有骨架，旧 UI（`DEV_DEBUG/ContentView`）功能可用但仍使用已弃用的 sudo 密码方式。数据持久化采用 Core Data 存储单个 JSON blob 的粗糙方案，无法支撑路由分组等结构化需求。用户需要一个符合 Apple 设计规范、支持路由分组管理、能清晰展示系统路由状态的现代化界面。

## What Changes

- **全新 NavigationSplitView 布局**：采用 Sidebar + Content 两栏布局替代当前的 SegmentedControl 切换方式，支持窗口自适应（窄窗口时 Sidebar 自动折叠）
- **路由分组（Group）机制**：引入 Group 概念，用户可创建多个路由组（如 "Office VPN"、"Home VPN"），一条路由可属于多个 Group（多对多关系）
- **SwiftData 数据层重构**：从 Core Data + JSON blob 迁移到 SwiftData，建立 `RouteRule` 和 `RouteGroup` 两个 @Model，支持多对多关系
- **路由 CRUD 完整流程**：通过 Sheet 表单实现路由的添加、编辑、删除，支持 CIDR 格式输入并自动计算子网掩码
- **系统路由表查看**：展示完整系统路由表，支持搜索和过滤，自动标记由本应用添加的路由（分组显示 + 高亮）
- **路由状态管理**：每条路由有全局 isActive 状态，通过 Toggle 直接控制路由在系统中的添加/删除
- **服务层重构**：统一通过 `RouterService` 管理 XPC 通信，替代当前分散的 `RouterCoreConnector` / `ProcessHelper` 双路径
- **清理遗留代码**：移除 `DEV_DEBUG` 目录下的旧 UI、`ProcessHelper` 中的 sudo 密码方式、`PassEnterView` 等已弃用组件
- **最低系统要求提升至 macOS 15+**：以使用 SwiftData、NavigationSplitView 等现代 API

## Capabilities

### New Capabilities

- `route-group-management`: 路由分组（Group）的创建、编辑、删除，以及路由与分组的多对多关联管理
- `swiftdata-persistence`: 基于 SwiftData 的数据持久化层，包含 RouteRule 和 RouteGroup 模型及其关系
- `main-navigation`: NavigationSplitView 主界面布局，包含 Sidebar（All Routes / Groups / System Route Table）和自适应响应式设计
- `route-crud`: 路由规则的添加、编辑、删除完整流程，包含 Sheet 表单、CIDR 输入、输入验证
- `system-route-view`: 系统路由表的展示、搜索、过滤，以及用户添加路由的自动标记
- `route-activation`: 路由激活/停用的状态管理，通过 Toggle 控制系统路由表的实际变更
- `router-service`: 统一的路由操作服务层，封装 XPC 通信和 Helper 状态管理

### Modified Capabilities

（无现有 spec 需要修改，本次为全新 UI 重构）

## Impact

- **StaticRouter 目标**：几乎所有 `View/`、`Model/`、`Components/` 下的文件将被重写或替换
- **数据迁移**：从 Core Data 迁移到 SwiftData，需要处理已有用户数据的迁移（或提供重新导入机制）
- **Shared 目标**：`RouterCommand.swift` 可能需要扩展以支持新的查询类型（如获取系统路由表的结构化数据）
- **RouteHelper 目标**：本次不修改 Helper 核心逻辑，但需确保新服务层与现有 XPC 协议兼容
- **依赖项**：新增 SwiftData 框架依赖；保留 Blessed / SecureXPC 依赖
- **最低系统版本**：从当前版本提升至 macOS 15+
