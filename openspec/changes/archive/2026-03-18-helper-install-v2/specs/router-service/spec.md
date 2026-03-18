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
- `func installHelper(method: InstallMethod) async throws -> InstallResult`（**变更**: 接受用户选择的安装方式参数）
- `func uninstallHelper() async throws`

#### Scenario: 通过 RouterService 安装 Helper（macOS 14+ 用户选择方式）
- **WHEN** 视图层调用 `routerService.installHelper(method: .smAppService)`
- **THEN** RouterService 将请求转发给 `PrivilegedHelperManager.install(method: .smAppService)`，执行对应安装流程，返回 `InstallResult`

#### Scenario: 通过 RouterService 安装 Helper（macOS 12–13）
- **WHEN** 视图层调用 `routerService.installHelper(method: .smJobBless)`
- **THEN** RouterService 将请求转发给 `PrivilegedHelperManager.install(method: .smJobBless)`，直接执行 SMJobBless 安装

#### Scenario: 通过 RouterService 激活路由（macOS 14+）
- **WHEN** 视图层调用 `routerService.activateRoute(rule)`（SwiftData RouteRule）
- **THEN** RouterService 构建 `RouterCommand`，通过 XPC 发送给 Helper，等待回复，成功则返回，失败则抛出 `RouterError`

#### Scenario: 通过 RouterService 激活路由（macOS 12–13）
- **WHEN** 视图层调用 `routerService.activateRouteMO(mo)`（Core Data RouteRuleMO）
- **THEN** RouterService 构建 `RouterCommand`，通过 XPC 发送给 Helper，等待回复，成功后更新 `mo.isActive = true` 并保存 Core Data 上下文

#### Scenario: XPC 通信失败
- **WHEN** XPC 调用 Helper 时连接失败（Helper 未运行）
- **THEN** RouterService 抛出 `RouterError.helperNotAvailable` 错误，`lastError` 属性更新，视图显示错误提示

### REMOVED Requirements

### Requirement: 移除遗留代码
**Reason**: upgrade() 原子升级路径不再需要。2.1.0 统一切换安装方式的流程为"卸载 → 重新选择 → 安装"，不再支持一键升级。
**Migration**: 用户通过 StatusBanner（info 样式）引导，在设置页完成卸载后重新选择安装方式。
