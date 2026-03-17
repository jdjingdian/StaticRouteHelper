## MODIFIED Requirements

### Requirement: RouterService 统一服务接口
系统 SHALL 提供 `RouterService` 作为所有路由操作和 Helper 通信的唯一入口。在 macOS 14+ 上 `RouterService` SHALL 遵循 `@Observable`（Observation 框架），通过类型化 `@Environment(RouterService.self)` 注入视图层级。在 macOS 12–13 上 SHALL 遵循 `ObservableObject`，通过 `@EnvironmentObject` 注入视图层级。两条路径 SHALL 暴露相同的公共接口：

- `helperStatus: HelperInstallStatus`
- `systemRoutes: [SystemRouteEntry]`
- `lastError: RouterError?`
- `func activateRoute(_ rule: RouteRule) async throws`（macOS 14+ 接受 SwiftData RouteRule）
- `func activateRouteMO(_ mo: RouteRuleMO) async throws`（macOS 12–13 接受 Core Data RouteRuleMO）
- `func deactivateRoute(_ rule: RouteRule) async throws`（macOS 14+）
- `func deactivateRouteMO(_ mo: RouteRuleMO) async throws`（macOS 12–13）
- `func refreshSystemRoutes() async throws`
- `func installHelper() throws`
- `func uninstallHelper() async throws`

#### Scenario: 通过 RouterService 激活路由（macOS 14+）
- **WHEN** 视图层调用 `routerService.activateRoute(rule)`（SwiftData RouteRule）
- **THEN** RouterService 构建 `RouterCommand`，通过 XPC 发送给 Helper，等待回复，成功则返回，失败则抛出 `RouterError`

#### Scenario: 通过 RouterService 激活路由（macOS 12–13）
- **WHEN** 视图层调用 `routerService.activateRouteMO(mo)`（Core Data RouteRuleMO）
- **THEN** RouterService 构建 `RouterCommand`，通过 XPC 发送给 Helper，等待回复，成功后更新 `mo.isActive = true` 并保存 Core Data 上下文

#### Scenario: XPC 通信失败
- **WHEN** XPC 调用 Helper 时连接失败（Helper 未运行）
- **THEN** RouterService 抛出 `RouterError.helperNotAvailable` 错误，`lastError` 属性更新，视图显示错误提示

### Requirement: SystemRouteEntry 数据结构
`SystemRouteEntry` 结构体及 `refreshSystemRoutes()` 解析逻辑不依赖 SwiftData 或 Observation 框架，SHALL 在 macOS 12+ 上完整可用，行为不变。

#### Scenario: 解析标准 netstat 输出（所有 OS 版本）
- **WHEN** 在 macOS 12–14+ 上调用 `refreshSystemRoutes()`，netstat 返回包含 "default 192.168.1.1 UGScg en0" 的行
- **THEN** 解析为 `SystemRouteEntry(destination: "default", gateway: "192.168.1.1", flags: "UGScg", networkInterface: "en0", expire: "")`

### Requirement: 错误反馈机制
错误反馈机制（`lastError`、`RouterError` 类型）在所有支持的 OS 版本上行为不变。在 macOS 12–13 上，由于 `RouterService` 遵循 `ObservableObject`，`lastError` 属性标注 `@Published`，视图通过标准 SwiftUI 数据流自动响应。

#### Scenario: 路由命令执行失败时显示错误（macOS 12–13）
- **WHEN** 用户在 macOS 13 上激活路由，route 命令返回 "route: writing to routing socket: File exists"
- **THEN** `lastError` 更新，UI 显示错误提示，行为与 macOS 14+ 一致

### Requirement: 移除遗留代码
此需求不变，遗留代码清理在所有部署目标版本上均适用。

#### Scenario: 清理后编译通过
- **WHEN** 所有遗留代码移除完毕，构建目标为 macOS 12.0
- **THEN** StaticRouter target 在 macOS 12.0 deployment target 下编译成功，无对已删除文件的引用
