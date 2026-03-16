## ADDED Requirements

### Requirement: RouterService 统一服务接口
系统 SHALL 提供 `RouterService`（@Observable 类）作为所有路由操作和 Helper 通信的唯一入口。RouterService SHALL 通过 SwiftUI Environment 注入到视图层级中。

RouterService SHALL 暴露以下接口：
- `helperStatus: HelperInstallStatus`（Helper 安装状态）
- `systemRoutes: [SystemRouteEntry]`（系统路由表缓存）
- `lastError: RouterError?`（最近一次操作错误）
- `func activateRoute(_ rule: RouteRule) async throws`
- `func deactivateRoute(_ rule: RouteRule) async throws`
- `func refreshSystemRoutes() async throws`
- `func installHelper() throws`
- `func uninstallHelper() async throws`

#### Scenario: 通过 RouterService 激活路由
- **WHEN** 视图层调用 `routerService.activateRoute(rule)`
- **THEN** RouterService 构建 `RouterCommand`，通过 XPC 发送给 Helper，等待回复，成功则返回，失败则抛出 `RouterError`

#### Scenario: XPC 通信失败
- **WHEN** XPC 调用 Helper 时连接失败（Helper 未运行）
- **THEN** RouterService 抛出 `RouterError.helperNotAvailable` 错误

### Requirement: SystemRouteEntry 数据结构
系统 SHALL 提供 `SystemRouteEntry` 结构体，用于表示系统路由表中的一条条目，包含：
- `destination: String`
- `gateway: String`
- `flags: String`
- `networkInterface: String`
- `expire: String`

RouterService SHALL 能够解析 `netstat -nr -f inet` 的输出为 `[SystemRouteEntry]` 数组。解析逻辑 SHALL 按空白字符分割每行，跳过表头行，健壮处理不同格式。

#### Scenario: 解析标准 netstat 输出
- **WHEN** netstat 返回包含 "default 192.168.1.1 UGScg en0" 的行
- **THEN** 解析为 SystemRouteEntry(destination: "default", gateway: "192.168.1.1", flags: "UGScg", networkInterface: "en0", expire: "")

#### Scenario: 解析包含 expire 字段的行
- **WHEN** netstat 返回包含过期时间的行
- **THEN** 正确解析 expire 字段

### Requirement: 错误反馈机制
RouterService SHALL 将操作错误通过 `lastError` 属性暴露给 UI 层。UI 层 SHALL 通过 Alert 或 Toast 方式将错误信息展示给用户。

RouterError SHALL 至少包含以下错误类型：
- `.helperNotAvailable`：Helper 未安装或不可达
- `.commandFailed(exitCode: Int32, stderr: String)`：route 命令执行失败
- `.xpcError(String)`：XPC 通信错误

#### Scenario: 路由命令执行失败时显示错误
- **WHEN** 用户激活路由，route 命令返回 "route: writing to routing socket: File exists"
- **THEN** UI 显示错误提示："路由添加失败：该路由已存在"（或类似的用户友好信息）

### Requirement: 移除遗留代码
本次重构 SHALL 移除以下遗留组件：
- `ProcessHelper.swift`（sudo 密码方式）
- `RouterCoreConnector.swift`（旧 ObservableObject 包装）
- `AppCoreConnector.swift`（旧 ObservableObject 包装）
- `CoreDataManager.swift`（旧 Core Data 管理器，迁移完成后移除）
- `DEV_DEBUG/` 目录下所有视图文件（`ContentView.swift`、`ContentViewDev.swift`、`PassEnterView.swift`、`RouteEnterView.swift` 等）
- `LocationProfiles.swift` 和 `LocationProfileSwitcher.swift`（被 RouteGroup 替代）
- `DataModel.xcdatamodeld`（旧 Core Data 模型，迁移完成后移除）

#### Scenario: 清理后编译通过
- **WHEN** 所有遗留代码移除完毕
- **THEN** StaticRouter target 编译成功，无对已删除文件的引用
