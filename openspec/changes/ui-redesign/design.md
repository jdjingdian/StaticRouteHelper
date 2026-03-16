## Context

StaticRouter 是一个 macOS 工具应用，用于管理系统静态路由表。当前应用处于新旧 UI 交替的过渡状态：

- **旧 UI**（`DEV_DEBUG/ContentView`）功能可用，但使用已弃用的 `sudo` 密码方式执行路由命令
- **新 UI**（`MainWindow`）仅有骨架代码，大部分视图为占位符
- **数据层**使用 Core Data 将路由列表序列化为单个 JSON blob 存储，无法支撑分组等结构化需求
- **服务层**存在 `ProcessHelper`（旧 sudo 方式）和 `RouterCore`（新 XPC 方式）两套并行路径
- **Privileged Helper**（`RouteHelper`）通过 SMJobBless 机制安装，使用 SecureXPC 通信，执行 `/sbin/route` 和 `/usr/sbin/netstat` 命令

本次重构目标是在 `newui_dev` 分支上完成 UI 和数据层的现代化改造，保持 Helper 层基本不变。

## Goals / Non-Goals

**Goals:**

- 使用 SwiftData 替代 Core Data，建立 `RouteRule` 和 `RouteGroup` 多对多数据模型
- 实现符合 Apple HIG 的 NavigationSplitView 两栏布局（Sidebar + Content）
- 完成路由 CRUD 完整流程（添加、编辑、删除、激活/停用）
- 实现路由分组（Group）功能，支持多对多关联
- 展示系统路由表并标记用户添加的路由
- 统一服务层，所有路由操作通过 XPC → Helper 执行
- 清理遗留代码（DEV_DEBUG、ProcessHelper、PassEnterView 等）

**Non-Goals:**

- 不修改 RouteHelper（Privileged Helper）的核心逻辑
- 不迁移到 PF_ROUTE socket（后续独立变更）
- 不迁移到 SMAppService（macOS 13+ 新 API，后续独立变更）
- 不实现 Network Extension 方案
- 不做完整的国际化/本地化（但代码结构应支持后续添加）
- 不上架 App Store

## Decisions

### 决策 1：使用 SwiftData 替代 Core Data

**选择**：SwiftData

**替代方案**：
- Core Data（正确使用多实体模型）：可行，但 API 较重，@Model 方式更 Swifty
- JSON 文件 + Codable：最简单，但缺少关系模型支持，多对多需要手动维护
- SQLite (GRDB)：高效灵活，但引入额外依赖，且无法利用 @Query 的响应式能力

**理由**：
- 目标最低系统版本为 macOS 15+，SwiftData 完全可用且稳定
- @Model 宏 + @Query 与 SwiftUI 天然集成，数据变更自动驱动 UI 更新
- 原生支持多对多关系（通过数组属性互相引用）
- 相比当前 Core Data JSON blob 方案，数据结构更清晰、查询更高效
- 不需要引入第三方依赖

**数据模型设计**：

```
┌──────────────────────────┐              ┌──────────────────────────┐
│  @Model RouteGroup       │              │  @Model RouteRule        │
├──────────────────────────┤              ├──────────────────────────┤
│  id: UUID                │    many-to-  │  id: UUID                │
│  name: String            │◄────many────►│  network: String         │
│  iconName: String?       │              │  prefixLength: Int       │
│  sortOrder: Int          │              │  gatewayType: GatewayType│
│  createdAt: Date         │              │  gateway: String         │
│  routes: [RouteRule]     │              │  isActive: Bool          │
│                          │              │  groups: [RouteGroup]    │
└──────────────────────────┘              │  createdAt: Date         │
                                          └──────────────────────────┘

enum GatewayType: String, Codable {
    case ipAddress   // 通过 IP 网关
    case interface   // 通过网络接口（如 utun3）
}
```

**关键设计点**：
- `prefixLength: Int` 替代 `mask: String`，内部统一使用 CIDR 前缀长度（如 24），需要时再计算子网掩码字符串
- `isActive: Bool` 是全局状态，表示该路由当前是否在系统路由表中生效。不是 per-group 状态
- `RouteGroup.routes` 和 `RouteRule.groups` 构成 SwiftData 的多对多反向关系
- 删除 Group 时，只解除关联，不删除 RouteRule 本身
- 无 Group 关联的 RouteRule 仍然存在，在 "All Routes" 视图中可见

### 决策 2：NavigationSplitView 两栏布局

**选择**：两栏布局（Sidebar + Detail），编辑操作使用 Sheet

**替代方案**：
- 三栏布局（Sidebar + List + Detail Inspector）：对路由数据来说 Detail 面板会显得空旷
- SegmentedControl 切换 + Location Picker（当前方案）：无法同时展示分组结构

**理由**：
- NavigationSplitView 是 macOS 上标准的内容组织方式（System Settings、Mail、Notes）
- 两栏在视觉上更紧凑，适合路由这种字段不多的数据
- Sidebar 天然支持分组和层级结构
- macOS 15 的 NavigationSplitView 内置 sidebar 折叠和窗口自适应

**Sidebar 结构**：

```
┌────────────────────┐
│  All Routes         │  ← NavigationLink，显示所有路由
│                     │
│  GROUPS             │  ← Section header
│  ├── Office VPN     │  ← 每个 RouteGroup 一个条目
│  ├── Home VPN       │
│  └── Lab Network    │
│                     │
│  SYSTEM             │  ← Section header
│  └── Route Table    │  ← 系统路由表视图
│                     │
│  ┌─────┐  ┌─────┐  │
│  │  +  │  │  ⚙️  │  │  ← 底部工具栏
│  └─────┘  └─────┘  │
└────────────────────┘
```

**窗口自适应策略**：
- 默认窗口大小：约 800×600
- 最小窗口宽度：约 500（此时 sidebar 可折叠为 overlay）
- NavigationSplitView 的 `columnVisibility` 绑定 + `.navigationSplitViewColumnWidth(min:ideal:max:)` 控制列宽
- 无需手动 GeometryReader，利用 NavigationSplitView 原生的自适应行为

### 决策 3：路由编辑使用 Sheet 模态表单

**选择**：Sheet（模态表单）

**替代方案**：
- Inspector 侧边栏：需要三栏布局，增加复杂度
- Inline 编辑：多字段编辑体验差
- Popover：空间受限，不适合表单

**理由**：
- macOS 上 Sheet 是标准的创建/编辑模式（Mail 新邮件、Calendar 新事件）
- 添加和编辑共用同一个 Sheet 组件，减少代码重复
- 模态避免用户在编辑中途误操作列表

**Sheet 表单结构**：

```
┌────────────────────────────────────┐
│  添加路由 / 编辑路由                │
│                                     │
│  网络地址                           │
│  ┌──────────────────┐ / ┌────┐     │
│  │ 192.168.4.0      │   │ 24 │     │
│  └──────────────────┘   └────┘     │
│  = 255.255.255.0                    │  ← 自动计算显示
│                                     │
│  路由方式                           │
│  ◉ 网关 IP     ○ 网络接口           │
│  ┌──────────────────────────────┐  │
│  │ 10.0.0.1                     │  │
│  └──────────────────────────────┘  │
│                                     │
│  所属分组                           │
│  ☑ Office VPN                       │
│  ☑ Home VPN                         │
│  ☐ Lab Network                      │
│                                     │
│           [取消]        [保存]       │
└────────────────────────────────────┘
```

### 决策 4：CIDR 前缀长度作为内部表示

**选择**：存储 `prefixLength: Int`，需要时计算子网掩码

**替代方案**：
- 存储子网掩码字符串（当前方式）：用户输入不友好，占用空间大
- 同时存储两者：冗余

**理由**：
- CIDR 是现代网络配置的标准表示方式
- 前缀长度到子网掩码的转换是确定性的，无需存储两份
- 用户输入时只需选择/输入一个数字（如 24），而非完整子网掩码
- 向 `/sbin/route` 发送命令时，在服务层转换为子网掩码格式

### 决策 5：系统路由表中标记用户路由的方式

**选择**：分组显示 + 行高亮（Accent Color 背景色）

**理由**：
- 系统路由表视图分为两个 Section："My Routes"（用户添加的路由）和 "System Routes"（其余路由）
- "My Routes" section 中的行使用浅色 Accent Color 背景（如 `.blue.opacity(0.1)`），提供视觉区分
- 匹配逻辑：将系统路由表条目的 (destination, gateway/interface) 与 SwiftData 中的 RouteRule 进行匹配

### 决策 6：统一服务层架构

**选择**：创建 `RouterService` 作为唯一的路由操作入口

**当前问题**：
- `RouterCore`（struct）+ `RouterCoreConnector`（ObservableObject 包装）层次多但功能少
- `ProcessHelper` 仍然存在，旧 UI 仍在使用
- `commandReply` 仅 print 到控制台，不反馈给 UI

**新设计**：

```
┌──────────────────────────────────────────┐
│  @Observable RouterService               │
├──────────────────────────────────────────┤
│                                          │
│  // 状态                                 │
│  helperStatus: HelperInstallStatus       │
│  systemRoutes: [SystemRouteEntry]        │
│  lastError: RouterError?                 │
│                                          │
│  // 路由操作                             │
│  func activateRoute(RouteRule) async throws
│  func deactivateRoute(RouteRule) async throws
│  func refreshSystemRoutes() async throws │
│                                          │
│  // Helper 管理                          │
│  func installHelper() throws             │
│  func uninstallHelper() async throws     │
│                                          │
│  // 内部                                 │
│  private xpcClient: XPCClient            │
│  private helperMonitor: HelperToolMonitor│
│                                          │
└──────────────────────────────────────────┘
```

**关键变化**：
- 使用 `@Observable`（macOS 14+）替代 `ObservableObject`，更简洁的观察机制
- 路由操作改为 `async throws`，调用方可以 await 结果并处理错误
- `systemRoutes` 作为 published 属性，解析 netstat 输出为结构化 `SystemRouteEntry` 数组
- 全局单例通过 SwiftUI Environment 注入（`.environment(routerService)`）
- 移除 `RouterCoreConnector`、`ProcessHelper`、`AppCoreConnector` 等冗余包装层

### 决策 7：输入验证策略

**选择**：实时验证 + 保存时拦截

**设计**：
- IP 地址字段：实时验证格式（IPv4 四段点分十进制，每段 0-255）
- 前缀长度：限制为 0-32 范围
- 网关/接口：非空验证
- 验证失败时：字段显示红色边框 + 错误提示文字，保存按钮禁用
- 验证逻辑封装在独立的 `RouteValidator` 工具类中，便于测试

## Risks / Trade-offs

### 风险 1：SwiftData 多对多关系的稳定性
- **风险**：SwiftData 的多对多关系在早期版本中存在一些已知 bug（如级联删除行为）
- **缓解**：目标为 macOS 15+，大部分已知问题已修复；删除 Group 时手动解除关联而非依赖级联删除

### 风险 2：Core Data 到 SwiftData 的数据迁移
- **风险**：已有用户数据存储在 Core Data 中，直接切换会导致数据丢失
- **缓解**：考虑到当前用户量极少且数据（路由规则）可以快速重建，采用简单策略：首次启动时检测旧 Core Data 存储是否存在，若存在则读取 JSON blob 并导入到 SwiftData，然后删除旧存储。如果迁移失败，提示用户手动重新添加路由。

### 风险 3：XPC 通信的错误反馈
- **风险**：当前 `commandReply` 仅 print 到控制台，用户无法看到路由操作是否成功
- **缓解**：新 `RouterService` 的 async throws 接口会将错误抛给 UI 层，通过 Alert 或 Toast 展示给用户

### 风险 4：netstat 输出解析的脆弱性
- **风险**：当前通过固定字符偏移量（magic number 93）解析 `netstat -nr` 输出，不同 macOS 版本可能格式变化
- **缓解**：改用按空白字符分割的方式解析每行，跳过表头行，更健壮。长期方案是迁移到 PF_ROUTE socket 直接获取结构化数据（列为后续 TODO）。

### 风险 5：Helper 未安装时的 UI 状态
- **风险**：用户打开应用但尚未安装 Helper，所有路由操作都会失败
- **缓解**：`RouterService.helperStatus` 驱动 UI 状态——当 Helper 未安装时，在主界面顶部显示横幅提示引导用户前往设置安装；路由 Toggle 禁用并显示提示

### Trade-off：两栏 vs 三栏布局
- **取舍**：选择两栏牺牲了路由详情的即时可见性（需要点击进入 Sheet 才能编辑），但换来了更紧凑的界面和更低的实现复杂度。对于路由这种字段少、操作频率低的数据，Sheet 模式足够高效。
