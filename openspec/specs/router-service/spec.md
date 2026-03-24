## 目的

定义 `RouterService` 作为应用中路由操作与 Helper 通信的统一入口，
并保证在不同 macOS 版本下对外接口一致、行为可预测。

## 需求

### 需求:RouterService 统一服务接口
系统必须提供 `RouterService` 作为所有路由操作和 Helper 通信的唯一入口。
在 macOS 14+ 上，`RouterService` 应遵循 `@Observable` 并支持类型化环境注入；
在 macOS 12-13 上，`RouterService` 应遵循 `ObservableObject` 并通过
`@EnvironmentObject` 注入。两条路径必须暴露一致的公共能力。

#### 场景:通过 RouterService 安装 Helper（macOS 14+ 用户选择方式）
- **当** 视图层调用 `routerService.installHelper(method: .smAppService)`
- **那么** RouterService 将请求转发给 `PrivilegedHelperManager.install(method: .smAppService)`，执行对应安装流程并返回 `InstallResult`

#### 场景:通过 RouterService 安装 Helper（macOS 12-13）
- **当** 视图层调用 `routerService.installHelper(method: .smJobBless)`
- **那么** RouterService 将请求转发给 `PrivilegedHelperManager.install(method: .smJobBless)`，执行 SMJobBless 安装

#### 场景:通过 RouterService 激活路由（macOS 14+）
- **当** 视图层调用 `routerService.activateRoute(rule)`（SwiftData RouteRule）
- **那么** RouterService 构建 `RouterCommand`，通过 XPC 发送给 Helper，等待回复并在成功时返回

#### 场景:通过 RouterService 激活路由（macOS 12-13）
- **当** 视图层调用 `routerService.activateRouteMO(mo)`（Core Data RouteRuleMO）
- **那么** RouterService 构建 `RouterCommand`，通过 XPC 发送给 Helper，等待回复，成功后更新 `mo.isActive = true` 并保存 Core Data 上下文

#### 场景:XPC 通信失败
- **当** XPC 调用 Helper 时连接失败（例如 Helper 未运行）
- **那么** RouterService 必须抛出 `RouterError.helperNotAvailable` 或映射后的通信错误，并更新 `lastError` 供界面展示

### 需求:RouterService 初始化必须容忍监听器降级
`RouterService` 在初始化过程中必须容忍 `HelperToolMonitor` 启动失败或部分失败；
无论监听器是否可用，`RouterService` 都必须完成初始化并对外提供可用实例。

#### 场景:监听器全部失败时完成初始化
- **当** `HelperToolMonitor.start` 返回“无可用监听源”
- **那么** `RouterService.init()` 必须完成，且应用主界面可正常进入

#### 场景:监听器部分成功时完成初始化
- **当** `HelperToolMonitor.start` 仅创建了部分监听源
- **那么** `RouterService` 必须按部分可用状态继续运行，不得抛出致命错误

### 需求:监听不可用时必须启用状态刷新兜底
当监听器不可用时，系统必须通过低频主动刷新保持 helper 安装状态可更新，
避免状态长期陈旧。

#### 场景:初始化后进入轮询兜底
- **当** `RouterService` 检测到监听不可用
- **那么** 系统必须启动低频刷新任务，周期性执行状态刷新并更新 `helperStatus`

#### 场景:应用恢复激活时即时刷新
- **当** 应用从后台回到前台或重新激活
- **那么** 系统必须立即触发一次 helper 状态刷新，而不是等待下一次轮询周期
