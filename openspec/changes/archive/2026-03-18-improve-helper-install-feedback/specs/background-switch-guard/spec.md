## MODIFIED Requirements

### Requirement: 系统设置引导弹窗
引导弹窗 SHALL 包含描述信息（说明为什么需要开启后台运行开关）和一个操作按钮。点击按钮后 SHALL 调用 `SMAppService.openSystemSettingsLoginItems()` 自动跳转到系统设置的"登录项与扩展"页面。

当 Helper 处于待生效状态时，系统 SHALL 在设置页提供持续可见的系统设置跳转入口；该入口的可见性 SHALL 由当前状态决定，不依赖用户是否关闭过引导弹窗。

#### Scenario: 用户点击引导按钮
- **WHEN** 用户在引导弹窗中点击"打开系统设置"按钮
- **THEN** 系统调用 `SMAppService.openSystemSettingsLoginItems()` 跳转到登录项设置页面，弹窗关闭

#### Scenario: 用户取消引导弹窗
- **WHEN** 用户在引导弹窗中点击"取消"或关闭弹窗
- **THEN** 弹窗关闭，不跳转系统设置，安装/卸载操作不执行

#### Scenario: 取消弹窗后设置页仍有入口
- **WHEN** 用户取消引导弹窗后，Helper 仍为待生效状态
- **THEN** 设置页显示可点击的系统设置入口，用户无需等待再次弹窗即可继续授权流程

### Requirement: 后台开关状态实时监听
在 macOS 14+ 上，系统 SHALL 通过混合方案监听 `SMAppService.status` 的变化：
1. 订阅 `NSApplication.didBecomeActiveNotification`，App 回到前台时立即刷新状态
2. 使用 `Timer.publish(every: 10, on: .main, in: .common)` 低频轮询，覆盖 App 始终在前台的场景（如分屏）
3. 在安装成功后启动短时快速刷新窗口，窗口内 SHALL 以 500ms 或更高频率轮询状态，并在窗口结束后回退到常规低频轮询

状态变化 SHALL 通过 `PrivilegedHelperManager` 的 `@Published` 属性反映到 UI。

#### Scenario: 用户在系统设置中关闭开关后切回 App
- **WHEN** 用户在系统设置中关闭 Static Router 的后台运行开关，然后切回 App
- **THEN** App 在 `didBecomeActive` 时刷新状态，`isPendingApproval` 变为 `true`，UI 相应更新

#### Scenario: 用户在分屏模式下关闭开关
- **WHEN** 用户在分屏模式下同时显示 App 和系统设置，在系统设置中关闭开关
- **THEN** App 在 10 秒内通过定时轮询检测到变化，`isPendingApproval` 更新为 `true`

#### Scenario: 安装成功后快速窗口缩短状态延迟
- **WHEN** 用户刚完成安装且系统状态尚在传播
- **THEN** 系统在短时快速窗口内以高频刷新尽快更新 `activeMethod` 与 `isPendingApproval`，并在窗口结束后恢复常规轮询

#### Scenario: 用户开启开关后 App 感知
- **WHEN** 后台运行开关从关闭变为开启
- **THEN** App 检测到 `SMAppService.status` 从 `.requiresApproval` 变为 `.enabled`，`activeMethod` 更新为 `.smAppService`，`isPendingApproval` 变为 `false`

#### Scenario: SMJobBless 路径不受后台开关干扰
- **WHEN** 当前活动安装方法为 `smJobBless`
- **THEN** 后台开关状态变化不应将 `activeMethod` 改写为 `smAppService`

#### Scenario: macOS 12–13 不启用监听
- **WHEN** App 在 macOS 12–13 上运行
- **THEN** 不启动定时器轮询，不订阅 didBecomeActive 刷新逻辑（macOS 12–13 无 SMAppService）
