## ADDED Requirements

### Requirement: RouterService 条件式响应式框架
`RouterService` SHALL 在 macOS 14.0 及以上使用 `@Observable`（Observation 框架），在 macOS 12–13 使用 `ObservableObject` + `@Published`。两条路径 SHALL 在同一个源文件中通过 `#if canImport(Observation)` + `@available(macOS 14, *)` 条件编译分隔，业务逻辑（XPC 调用、路由操作、socket 监听）不重复。

#### Scenario: 在 macOS 14+ 编译时
- **WHEN** 构建目标系统为 macOS 14+
- **THEN** `RouterService` 使用 `@Observable` 宏，`helperStatus`、`systemRoutes`、`lastError` 属性无需 `@Published` 标注，视图通过类型化 `@Environment(RouterService.self)` 接收实例

#### Scenario: 在 macOS 12–13 编译时
- **WHEN** 构建目标系统为 macOS 12–13
- **THEN** `RouterService` 遵循 `ObservableObject`，所有需响应的属性标注 `@Published`，视图通过 `@EnvironmentObject var routerService: RouterService` 接收实例

### Requirement: Environment 注入按 OS 版本分支
应用入口 (`StaticRouteHelperApp`) SHALL 按 OS 版本将 `RouterService` 以正确方式注入 SwiftUI 环境：
- macOS 14+：`.environment(routerService)`（无 EnvironmentKey，依赖 `@Observable` 协议）
- macOS 12–13：`.environmentObject(routerService)`

#### Scenario: macOS 14+ 环境注入
- **WHEN** 应用在 macOS 14 上运行，`routerService` 作为 `@State` 持有
- **THEN** 视图层通过 `@Environment(RouterService.self)` 正确获取 `routerService`，无运行时崩溃

#### Scenario: macOS 12–13 环境注入
- **WHEN** 应用在 macOS 13 上运行，`routerService` 作为 `@StateObject` 持有
- **THEN** 视图层通过 `@EnvironmentObject var routerService: RouterService` 正确获取实例，无运行时崩溃

### Requirement: 两参数 onChange 降级
`RouteEditSheet.swift` 中所有 `.onChange(of:) { old, new in }` 两参数闭包 SHALL 在 macOS 12–13 路径上替换为 `.onChange(of:perform:)` 单参数形式（macOS 12+ 可用），功能等价。

#### Scenario: macOS 12 上编辑路由时字段联动
- **WHEN** 用户在 macOS 12 上编辑路由，修改网关类型选择器
- **THEN** 网关输入字段联动重置，行为与 macOS 14+ 一致
