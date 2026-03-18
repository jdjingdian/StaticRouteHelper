## 上下文

当前 Helper 状态监听在 macOS 14+ 采用 `didBecomeActive` + 10 秒定时轮询。该策略在“用户切回 App”时反馈及时，但对 SMJobBless 安装后的即时状态刷新不够友好，常出现安装成功后 UI 仍停留数秒的体感延迟。

另外，安装后若进入待生效状态（`pendingActivation`），目前主要依赖一次性弹窗引导打开系统设置。用户误点取消后，设置页缺少持续入口，导致路径中断。

在问题排查中还观察到：当 SMAppService 与 SMJobBless 使用同一 label/mach service 时，系统可能把后台服务注册与 privileged helper 进程混淆，表现为：
- `activeMethod` 在 `smAppService/smJobBless` 间抖动；
- XPC 请求出现 `SecureXPC` 连接错误；
- SMJobBless 卸载“XPC 已成功回包但状态长期不收敛”，最终回退 osascript。

相关约束：
- 保持现有安装权限与调用链不变（`authorizeAndBless` / `SMAppService`）。
- 保持低资源占用，不引入长期高频轮询。
- 兼容 macOS 12–13（仅 SMJobBless，无 `SMAppService` 后台开关语义）。
- 避免新增交互破坏：SMJobBless 仍作为优先卸载主路径，osascript 仅作为兜底。

## 目标 / 非目标

**目标：**
- 缩短安装成功到 UI 状态更新的可感知延迟，优先改善 SMJobBless 路径体验。
- 在待生效状态下提供持续可见的系统设置跳转入口，避免仅依赖一次性弹窗。
- 消除 SMAppService 与 SMJobBless 的服务命名冲突，确保状态判定和 XPC 通道稳定。
- 保证 SMJobBless 卸载在 XPC 主路径可收敛，减少不必要的管理员弹窗回退。
- 变更范围限制在状态刷新策略与设置页交互层，不改变安装协议与数据模型。

**非目标：**
- 不重构 Helper 安装架构或替换现有安装方式。
- 不引入新的后台常驻高频监测机制。
- 不调整主窗口 Banner 逻辑优先级。

## 决策

### 决策 1：引入“安装后短时加速轮询”而不是全局提升频率

在 `PrivilegedHelperManager` 中保留现有 10 秒低频轮询作为基线；新增安装后的短时观察窗口（例如 3~5 秒），在窗口内按 250ms 或 500ms 执行快速 `refreshState()`，窗口结束后自动回退到基线策略。

**理由：**
- 直接解决“安装后几秒才更新”的核心痛点。
- 相比全局改为 250ms/500ms，资源开销可控，不会长期高频触发。
- 方案局部化，便于在 `installViaJobBless()` / `install(method:)` 成功路径接入。

**备选方案：**
- 全局轮询改为 500ms：实现简单，但长期性能代价高，且没有必要。
- 仅在安装结束调用一次 `refreshState()`：当前已存在，无法覆盖系统状态传播延迟。

### 决策 2：在待生效状态区域增加常驻“打开系统设置”按钮

在 `GeneralSettings_HelperStateView` 中，当 `helperStatus == .pendingActivation` 或 `helperManager.isPendingApproval == true` 时显示一个次级按钮，点击后调用 `SMAppService.openSystemSettingsLoginItems()`。

**理由：**
- 用户错过弹窗后仍有明确恢复路径。
- 与现有引导弹窗使用同一系统跳转 API，行为一致。
- 放在状态区域可与“待生效”文案形成就地闭环。

**备选方案：**
- 重复弹出 Alert：打断性更强，且用户容易形成“误触—关闭—再弹出”的负反馈。
- 只在主窗口 Banner 提供入口：不覆盖用户已进入设置页但停留在当前子页的场景。

### 决策 3：将按钮显示条件绑定到状态而非弹窗触发结果

按钮可见性基于当前真实状态（pending），不依赖用户是否取消过弹窗。

**理由：**
- 逻辑可预测，避免“取消一次后才出现按钮”等隐式状态机。
- 与后续状态刷新同步，授权完成后按钮自动消失。

### 决策 4：为 SMAppService 与 SMJobBless 拆分 label/mach service

保留 SMJobBless 的 `cn.magicdian.staticrouter.helper`，新增 SMAppService 专用 `cn.magicdian.staticrouter.service`（独立 launchd plist 与 mach service），并在 App 侧按安装方法选择对应 XPC 通道。

**理由：**
- 从根源消除同名竞争，避免后台开关状态影响 SMJobBless 进程判定。
- 让安装状态、连接错误与卸载路径可观测性更清晰。
- 拆分后可独立演进两条安装路径，不再互相污染。

### 决策 5：SMJobBless 卸载采用“XPC 主路径 + 状态收敛校验 + 必要时回退”

App 侧保持 XPC 卸载主路径，设置超时保护（当前 3s）和短期收敛轮询。Helper 侧卸载改为同进程延迟执行并直接删除 blessed artifacts，避免子进程/launchctl 竞态。

**理由：**
- 维持无额外授权的主路径体验。
- 在异常场景仍保留 osascript 兜底，兼顾确定性与用户体验。
- 通过关键日志可清晰区分“未触发”“触发后失败”“已落地”。

## 风险 / 权衡

- 安装后短时高频刷新可能增加少量主线程工作量 → 仅在短窗口内启用，并复用现有 `refreshState()`，避免额外重计算。
- 快速轮询窗口过短可能仍偶发延迟，过长则造成无谓开销 → 采用可调参数（间隔与持续时间常量化），根据测试微调。
- 待生效按钮在 macOS 12–13 上无意义 → 通过可用性与状态条件限制，确保仅在支持路径显示。
- SMAppService 在 ad-hoc 签名场景可能返回 `Operation not permitted` → 通过明确日志暴露，不阻断 SMJobBless 路径验证。
- 卸载收敛窗口过短会放大误回退概率 → 保持参数可调并结合日志持续校准。

## Migration Plan

1. 在 `PrivilegedHelperManager` 增加安装后短时加速刷新机制，并接入安装成功路径。
2. 在设置页待生效状态下新增“打开系统设置”入口，复用现有系统跳转 API。
3. 将 SMAppService 的 launchd 配置拆分为独立 `service` label/mach service，并更新打包清单。
4. 将 App 侧常量与 XPC 客户端拆分为 SMJobBless / SMAppService 双通道。
5. 修复 helper 自卸载执行模型（同进程延迟执行）并增强关键日志。
6. 补充本地化键并验证中英文文案。
7. 手动验证：SMJobBless 安装后状态更新时间、待生效时取消弹窗后的可恢复路径、SMJobBless 卸载 XPC 主路径收敛。

回滚策略：若发现异常，可移除短时加速逻辑并保留原 10 秒轮询；按钮入口可独立保留，不影响安装主流程。

## Open Questions

- 短时轮询默认间隔采用 250ms 还是 500ms：当前 500ms，可继续观察。
- 短时轮询窗口持续时长采用 3 秒还是 5 秒：当前 3 秒，可按日志再调。
- XPC 卸载超时采用 3 秒还是 8 秒：当前回调为 3 秒；若现场网络/系统抖动较大，可按数据回调。
