## Context

StaticRouteHelper 是一个 macOS 菜单栏应用，通过 XPC Helper（拥有 root 权限）调用 `/sbin/route` 来增删静态路由，并通过 `netstat -nr -f inet` 获取系统路由表快照。

当前路由读取链路存在两个问题：

1. **文本解析脆弱**：`netstat` 输出中目标地址会省略末尾 `.0`（如 `192.168.3` 而非 `192.168.3.0`），`RouteStateCalibrator` 做字符串直接比较，导致已激活路由被误判为未激活。`SystemRouteTableView` 已有 `normalizeDestination()` 修复此问题，但 `RouteStateCalibrator` 未复用该逻辑。

2. **无实时感知**：路由状态仅在 App 启动时校准一次。VPN 软件、网络切换、手动 `route delete` 等操作会在运行时删除路由，但 App 的 `isActive` 不会自动更新，导致 UI 显示与实际状态不符。

架构约束：
- XPC Helper 持有 root 权限，负责所有写操作
- App 进程无 root 权限，但可以以只读方式打开 `PF_ROUTE` socket（内核允许无特权进程监听路由事件）
- 持久化层为 SwiftData（`@Model` / `ModelContext`），必须在 `@MainActor` 上写入
- `RouterService` 是 `@Observable` 单例，通过 SwiftUI `Environment` 注入

## Goals / Non-Goals

**Goals:**
- 用 `PF_ROUTE` raw socket 替换 `netstat` 文本解析，精确获取系统路由表
- 在 App 进程内实现持续监听线程，实时响应 `RTM_ADD` / `RTM_DELETE` 事件
- 修复 `RouteStateCalibrator` 的 destination 规范化 bug
- 将所有现有硬编码 UI 字符串迁移至 `Localizable.strings`（en / zh-Hans）

**Non-Goals:**
- Helper 侧写操作迁移（`/sbin/route` → PF_ROUTE write）—— 留给 v1.3.0
- 路由断开时自动重新激活（语义确定为"只读同步现实状态"）
- GitHub Actions CI
- SMAppService 迁移

## Decisions

### D1：路由读取方在 App 进程，而非 Helper

**选择**：App 进程自己打开 `PF_ROUTE` socket 读取和监听，Helper 仅保留写操作。

**理由**：监听路由变化（`SOCK_RAW` + `AF_ROUTE`）不需要 root 权限，macOS 内核允许无特权进程订阅路由事件。这避免了引入 XPC 反向通知机制的复杂度，也保持了 Helper 职责的单一性。

**被排除的方案**：
- **Helper 监听 + XPC 推送**：需要在 SecureXPC 上构建反向通知通道，复杂且 Helper 的 XPC 服务设计为请求-响应模式，改造成本高。
- **App 轮询 netstat**：解决实时性问题但放大了文本解析的脆弱性，属于错误方向。
- **DistributedNotification**：跨进程通知不安全，且仍需要 Helper 侧有监听逻辑。

### D2：PF_ROUTE socket 读取替换 RouterCommand.BuildPrintRouteCommand()

**选择**：新增 `SystemRouteReader`（纯 Swift struct/enum），封装 `socket(PF_ROUTE, SOCK_RAW, AF_UNSPEC)` + `sysctl(NET_RT_DUMP)` 读取当前路由表快照，以及持续读取 socket 的监听循环。

**理由**：`sysctl(NET_RT_DUMP)` 可以一次性 dump 整张路由表，格式为内核结构体（`rt_msghdr` + `sockaddr`），精度高，无需文本解析。`RouterService.refreshSystemRoutes()` 改为调用此接口。

**数据结构**：解析后的每条路由仍映射为现有的 `SystemRouteEntry`（destination / gateway / flags / networkInterface / expire），保持下游兼容。

**被排除的方案**：
- **保留 netstat，只修复解析 bug**：治标不治本，仍是进程调用 + 文本解析，无法支持实时监听。

### D3：监听线程架构

**选择**：在 `RouterService` 内使用 Swift `Task`（结构化并发）运行监听循环，读取 `PF_ROUTE` socket 的阻塞 `read()`，通过 `@MainActor` 回调更新 SwiftData。

```
App 进程内部
══════════════════════════════════════════════════════

RouterService (@Observable, @MainActor)
  │
  ├── Task (background) ──────────────────────────────┐
  │     │                                             │
  │     │  socket(PF_ROUTE, SOCK_RAW, AF_UNSPEC)      │
  │     │  └─ 阻塞 read() 等待 RTM_* 消息             │
  │     │                                             │
  │     │  收到 RTM_ADD / RTM_DELETE                  │
  │     │  解析 rt_msghdr → destination + gateway     │
  │     │  MainActor.run { 更新 isActive }            │
  │     │                                             │
  │     └─ 循环 ────────────────────────────────────┘
  │
  └── systemRoutes: [SystemRouteEntry]  (已有)
```

**isActive 更新逻辑**：
- `RTM_DELETE`：找到 `network == destination && gateway == gateway` 的 `RouteRule`，设 `isActive = false`
- `RTM_ADD`：找到匹配的 `RouteRule`，设 `isActive = true`
- 不匹配任何用户路由的事件：更新 `systemRoutes` 快照，忽略 `isActive` 变更

**生命周期**：Task 随 `RouterService` 创建而启动，随 App 退出自动取消（`deinit` 中 cancel）。

**被排除的方案**：
- **DispatchQueue + CFSocket**：可行，但与 Swift 并发生态割裂，`@MainActor` 集成需要额外桥接。
- **Combine publisher**：封装 socket 为 publisher 过度工程化，且 socket 是 C API，桥接复杂。

### D4：本地化策略——String(localized:) over NSLocalizedString

**选择**：新字符串使用 Swift 6 风格的 `String(localized: "key", bundle: .main)` 或直接 `String(localized: "key")`（在 SwiftUI 中优先使用 `LocalizedStringKey` 隐式转换）。存量迁移时保持一致，避免混用 `NSLocalizedString`。

**Key 命名规范**：使用语义化 key（如 `"route.list.empty.title"`）而非将英文原文作为 key，便于维护多语言。

**被排除的方案**：
- **NSLocalizedString**：Objective-C 风格，与 Swift 现代 API 不一致。
- **以英文原文为 key**：key 变更时需要同步改所有 `.strings` 文件，脆弱。

## Risks / Trade-offs

**[风险 1] PF_ROUTE 内核消息解析复杂度**
→ `rt_msghdr` 后跟可变数量的 `sockaddr`，需按 `rtm_addrs` bitmask 逐个解析，容易出错。
→ 缓解：单独封装 `SystemRouteReader`，充分单元测试边界情况（IPv4/IPv6/loopback），并保留 fallback 到 netstat 的能力（若解析失败降级）。

**[风险 2] Helper 侧 netstat XPC 路由废弃时序**
→ 本次只在 App 侧引入新读取方式，Helper 侧的 `BuildPrintRouteCommand()` 路径仍保留，待 v1.3.0 一起清理。
→ 需确保 `RouterService.refreshSystemRoutes()` 完全切换到新路径后，再移除旧接口调用（可用编译警告标记 deprecated）。

**[风险 3] 本地化 key 遗漏**
→ 手动扫描容易遗漏，特别是错误描述等动态字符串。
→ 缓解：使用 Xcode 的 "Export Localizations" 做验收，确保无未翻译条目。

**[风险 4] PF_ROUTE 事件在特殊网络场景下的噪音**
→ macOS 网络切换时会产生大量 RTM_DELETE/RTM_ADD 事件（默认路由变更、接口 up/down），可能触发频繁 SwiftData 写入。
→ 缓解：在匹配 `RouteRule` 前先过滤，只处理 destination + gateway 命中用户路由的事件，非用户路由事件只更新 `systemRoutes` 快照不触发 SwiftData 写。

## Migration Plan

1. 新增 `SystemRouteReader.swift` 和监听逻辑，保持 `RouterService` 对外接口不变
2. `refreshSystemRoutes()` 内部切换到 `SystemRouteReader`，移除 `parseNetstatOutput()`
3. 修复 `RouteStateCalibrator` 的 `normalizeDestination`
4. 本地化抽取（可并行进行，不影响功能逻辑）
5. 版本号 `MARKETING_VERSION` 从 `1.1.0` 改为 `1.2.0`

无需数据迁移（SwiftData schema 不变）。无 rollback 风险（socket 读取失败可降级到原有 netstat 路径，待稳定后再移除旧路径）。
