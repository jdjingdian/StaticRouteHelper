## Context

Static Router 使用 Privileged Helper 以 root 权限操作系统路由表。当前架构在 macOS 14+ 上自动尝试 SMAppService，失败后回退到 SMJobBless。测试发现两种方式都受"后台运行"开关约束，回退机制名存实亡。同时，部分用户偏好 SMJobBless 的独立进程可见性。2.1.0 需要将安装方式选择权交给用户，并补全对系统设置开关状态的感知能力。

当前关键组件：
- `PrivilegedHelperManager`：安装策略编排中心，持有 `activeMethod` 和 `isPendingApproval` 状态
- `RouterService`：上层服务，桥接 UI 与 PrivilegedHelperManager，提供 `helperStatus`
- `HelperToolMonitor`：文件系统监听（仅覆盖 SMJobBless 路径）
- `HelperNotInstalledBanner`：主窗口顶部黄色警告横幅
- `GeneralSettings_HelperStateView`：设置页 Helper 状态显示与安装按钮

日志方面，Helper 端使用 `NSLog`，App 端使用 `print("[tag]")`，无统一日志框架。

## Goals / Non-Goals

**Goals:**
- macOS 14+ 用户可以自主选择 SMAppService 或 SMJobBless 安装方式
- 切换安装方式必须先卸载当前 Helper，避免两种方式冲突
- 应用能感知"后台运行"开关状态变化，在开关关闭时阻断安装/卸载操作并引导用户
- 统一 UI 横幅组件风格，复用样式但按场景区分颜色
- 关键安装/卸载流程具备 INFO 级别结构化日志

**Non-Goals:**
- 不改变 macOS 12–13 的安装流程（保持纯 SMJobBless）
- 不引入新的外部依赖
- 不改变 Helper 端 (RouteHelper) 的功能逻辑（路由写入、自卸载）
- 不做批量安装方式迁移工具
- 不监听 SMJobBless 路径的开关状态（SMJobBless 无等效 API）

## Decisions

### Decision 1: 用户主动选择安装方式，而非自动回退

**选择**: 在 macOS 14+ 上，用户点击"安装"后弹出方法选择对话框（Sheet），明确选择 SMAppService 或 SMJobBless。

**替代方案**:
- A) 保持自动尝试 + 回退：已证实两种方式都受开关限制，回退无实际作用
- B) 仅提供 SMAppService，移除 SMJobBless：部分用户偏好独立进程的可见性（可通过 `ps` 看到）

**理由**: 既然两种方式都有存在价值且都受相同约束，将选择权交给用户是最诚实的设计。推荐 SMAppService 但不强制。

### Decision 2: UserDefaults 存储安装方式偏好

**选择**: 使用 `UserDefaults` 存储用户的安装方式偏好（key: `preferredInstallMethod`），仅 macOS 14+ 需要。

**替代方案**:
- A) SwiftData：对于单个枚举值过于重量级，且 macOS 12–13 需要额外 Core Data 路径
- B) 不持久化，纯运行时检测：无法在卸载后记住用户偏好，重新安装时无法预选
- C) `@AppStorage`：底层也是 UserDefaults，但提供 SwiftUI 绑定便利性

**理由**: 运行时通过 `PrivilegedHelperManager.refreshState()` 检测实际激活的方式（真实状态），UserDefaults 仅用于记住用户偏好（卸载后重新安装时的默认选项）。两者职责分明。实际使用 `@AppStorage` 包装以获得 SwiftUI 响应性。

### Decision 3: didBecomeActive + 低频 Timer 混合监听

**选择**: 通过两种机制监听 `SMAppService.status` 变化：
1. `NSApplication.didBecomeActiveNotification` — 覆盖用户去系统设置切换后返回的场景
2. `Timer.publish(every: 10, on: .main, in: .common)` — 覆盖分屏/多桌面下 App 始终在前台的场景

监听逻辑集成到 `PrivilegedHelperManager` 内部，仅 macOS 14+ 激活。

**替代方案**:
- A) 仅 didBecomeActive：不覆盖分屏场景
- B) 仅 Timer：增加不必要开销，且 didBecomeActive 场景下响应不够即时
- C) 监听 Service Management 数据库文件变化：未公开路径，受 SIP 保护，跨版本不稳定

**理由**: `SMAppService.status` 读取无 IPC 开销（内存级操作），10 秒轮询完全可忽略。混合方案以极低成本覆盖所有用户操作场景。Timer 使用 `.common` RunLoop mode，App 非活跃时自动暂停。

### Decision 4: 通用 StatusBanner 组件替换 HelperNotInstalledBanner

**选择**: 提取通用 `StatusBanner` View，接受 `BannerStyle`（`.warning` / `.info`）、消息文本、操作按钮参数。在 MainWindow 中按条件优先级显示：
1. `helperStatus != .installed` → `.warning`（浅黄色）"Helper 未安装"
2. `activeMethod == .smJobBless && macOS 14+` → `.info`（浅蓝色）"有更现代的部署方式"

两者互斥，只显示优先级最高的一个。

**理由**: 复用相同的布局结构（icon + message + Spacer + action button + padding + background + divider），仅通过样式枚举区分颜色和图标，保持 UI 风格统一。

### Decision 5: 移除 upgrade() 原子升级路径

**选择**: 删除 `PrivilegedHelperManager.upgrade()` 方法和 `StaticRouteHelperApp` 中的启动时升级弹窗。切换方式统一走"卸载 → 重新选择 → 安装"流程。

**替代方案**: 保留 `upgrade()` 作为快捷路径，同时支持手动卸载+重装。

**理由**: 统一为单一流程，减少代码路径和测试矩阵。主窗口蓝色 Banner 提供温和引导，用户可在设置页完成卸载+重装。

### Decision 6: os.Logger 结构化日志

**选择**: 使用 Apple 原生 `os.Logger`（macOS 11+），subsystem 为 `cn.magicdian.staticrouter`，在 App 端 Helper 管理相关逻辑使用 category `helper-management`。

**替代方案**:
- A) 保持 `print()`：不持久化，生产环境无法收集
- B) 第三方库（SwiftyBeaver/CocoaLumberjack）：引入不必要依赖

**理由**: `os.Logger` 零依赖，INFO 级别日志持久化到统一日志系统，可通过 Console.app 或 `log` CLI 按 subsystem 过滤。覆盖范围限于安装/卸载/状态变更的入口和出口，不做全面替换。

### Decision 7: 系统设置深度链接

**选择**: 使用 `SMAppService.openSystemSettingsLoginItems()` (macOS 13+) 跳转到登录项设置页面。

**替代方案**: `NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:..."))` — URL scheme 跨版本不稳定。

**理由**: `SMAppService.openSystemSettingsLoginItems()` 是 Apple 官方提供的 API，专为此场景设计，比 URL scheme 更可靠。macOS 13+ 可用，覆盖目标版本。

## Risks / Trade-offs

- **[Timer 轮询精度]** → 分屏场景下开关变化最多延迟 10 秒才反映到 UI。可接受，非关键操作。
- **[SMJobBless 开关检测盲区]** → 无法通过 API 检测 SMJobBless 安装是否受开关限制。缓解方案：SMJobBless 安装通过 `authorizeAndBless()` 尝试，失败时统一弹窗引导。
- **[upgrade() 移除的用户体验回退]** → 用户从 SMJobBless 切换到 SMAppService 需要两步操作（卸载 + 安装），比原来一键升级多一步。但流程更清晰可控，避免竞态问题。
- **[UserDefaults 偏好与实际状态不一致]** → 用户可能通过外部方式（命令行）安装/卸载 Helper，导致偏好记录过时。缓解方案：始终以 `refreshState()` 运行时检测为准，UserDefaults 仅影响选择器默认选项。
