## Why

当前 App 依赖 `netstat -nr` 文本输出解析路由表，且仅在启动时做一次性校准，无法感知运行时路由变化（VPN 切换、网络重连等场景会导致 `isActive` 状态失真）。同时，代码库中存在大量硬编码中文字符串，阻碍了后续国际化和代码可维护性。

## What Changes

- **替换 netstat 文本解析**：App 进程通过 `PF_ROUTE` raw socket 直接读取系统路由表，解析精确的内核路由消息（`RTM_*`），消除字符串匹配的脆弱性
- **新增实时路由监听**：App 进程维护一个后台监听线程，订阅 `PF_ROUTE` socket 事件，当系统路由发生 `RTM_ADD` / `RTM_DELETE` 变化时，自动更新受影响 `RouteRule` 的 `isActive` 状态（无需 root 权限）
- **修复 RouteStateCalibrator bug**：现有校准逻辑缺少 destination 规范化（"192.168.3" vs "192.168.3.0"），导致部分激活路由被误判为未激活
- **存量字符串本地化抽取**：扫描所有现有 Swift 文件，将硬编码 UI 字符串迁移至 `Localizable.strings`，覆盖 `en` / `zh-Hans` 两种语言，并作为后续开发的基本规范

**不在本次范围内**：
- Helper 侧写操作迁移（`/sbin/route` → PF_ROUTE socket write，留给 v1.3.0）
- GitHub Actions CI 配置
- SMJobBless → SMAppService 迁移

## Capabilities

### New Capabilities

- `pf-route-reader`: 通过 PF_ROUTE socket 精确读取系统路由表，替换 netstat 文本解析，作为路由表快照获取和状态校准的基础
- `route-change-monitor`: App 进程内的实时路由变化监听，订阅 PF_ROUTE socket 事件流，自动同步 `isActive` 状态到 SwiftData

### Modified Capabilities

（无已有 spec 需要修改）

## Impact

**代码变更**：
- `StaticRouter/Services/RouterService.swift`：移除 `parseNetstatOutput()`，新增 PF_ROUTE 读取和 socket 监听逻辑
- `StaticRouter/Services/RouteStateCalibrator.swift`：修复 destination 规范化 bug
- `Shared/RouterCommand.swift`：`BuildPrintRouteCommand()` 可在 App 侧直接读取路由后退役（Helper 侧的 netstat 调用移除）
- `Resources/Locale/en.lproj/Localizable.strings`、`zh-Hans.lproj/Localizable.strings`：大量新增条目
- 所有包含硬编码 UI 字符串的 Swift 文件：替换为 `String(localized:)` 调用

**依赖变更**：
- 新增 Darwin/BSD socket API（系统框架，无需额外 Swift Package）
- 无新增第三方依赖

**版本号**：v1.1.0 → v1.2.0（新功能，向后兼容）
