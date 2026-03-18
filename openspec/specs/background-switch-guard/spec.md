## ADDED Requirements

### Requirement: 安装/卸载前后台开关检查
在 macOS 14+ 上，执行 SMAppService 相关操作（注册、注销）前，系统 SHALL 检查 `SMAppService.daemon(...).status`。若状态为 `.requiresApproval`（表示后台运行开关关闭），系统 SHALL 阻断操作并弹出引导弹窗。对于 SMJobBless 安装操作，系统 SHALL 在 `authorizeAndBless()` 失败时同样弹出引导弹窗。

#### Scenario: SMAppService 安装时开关关闭
- **WHEN** 用户在 macOS 14+ 上选择 SMAppService 安装，但后台运行开关处于关闭状态
- **THEN** 系统不执行 `register()`，弹出引导弹窗说明需要开启后台运行开关

#### Scenario: SMAppService 卸载时开关关闭
- **WHEN** 用户尝试卸载 SMAppService 方式安装的 Helper，但后台运行开关处于关闭状态
- **THEN** 系统弹出引导弹窗，提示用户先开启后台运行开关后再执行卸载

#### Scenario: SMJobBless 安装时系统限制
- **WHEN** 用户在 macOS 14+ 上选择 SMJobBless 安装，`authorizeAndBless()` 因系统限制失败
- **THEN** 系统弹出引导弹窗，引导用户检查系统设置

#### Scenario: 开关已开启时正常操作
- **WHEN** 用户执行安装/卸载操作，后台运行开关处于开启状态
- **THEN** 操作正常执行，不弹出引导弹窗

### Requirement: 系统设置引导弹窗
引导弹窗 SHALL 包含描述信息（说明为什么需要开启后台运行开关）和一个操作按钮。点击按钮后 SHALL 调用 `SMAppService.openSystemSettingsLoginItems()` 自动跳转到系统设置的"登录项与扩展"页面。

#### Scenario: 用户点击引导按钮
- **WHEN** 用户在引导弹窗中点击"打开系统设置"按钮
- **THEN** 系统调用 `SMAppService.openSystemSettingsLoginItems()` 跳转到登录项设置页面，弹窗关闭

#### Scenario: 用户取消引导弹窗
- **WHEN** 用户在引导弹窗中点击"取消"或关闭弹窗
- **THEN** 弹窗关闭，不跳转系统设置，安装/卸载操作不执行

### Requirement: 后台开关状态实时监听
在 macOS 14+ 上，系统 SHALL 通过混合方案监听 `SMAppService.status` 的变化：
1. 订阅 `NSApplication.didBecomeActiveNotification`，App 回到前台时立即刷新状态
2. 使用 `Timer.publish(every: 10, on: .main, in: .common)` 低频轮询，覆盖 App 始终在前台的场景（如分屏）

状态变化 SHALL 通过 `PrivilegedHelperManager` 的 `@Published` 属性反映到 UI。

#### Scenario: 用户在系统设置中关闭开关后切回 App
- **WHEN** 用户在系统设置中关闭 Static Router 的后台运行开关，然后切回 App
- **THEN** App 在 `didBecomeActive` 时刷新状态，`isPendingApproval` 变为 `true`，UI 相应更新

#### Scenario: 用户在分屏模式下关闭开关
- **WHEN** 用户在分屏模式下同时显示 App 和系统设置，在系统设置中关闭开关
- **THEN** App 在 10 秒内通过定时轮询检测到变化，`isPendingApproval` 更新为 `true`

#### Scenario: 用户开启开关后 App 感知
- **WHEN** 后台运行开关从关闭变为开启
- **THEN** App 检测到 `SMAppService.status` 从 `.requiresApproval` 变为 `.enabled`，`activeMethod` 更新为 `.smAppService`，`isPendingApproval` 变为 `false`

#### Scenario: macOS 12–13 不启用监听
- **WHEN** App 在 macOS 12–13 上运行
- **THEN** 不启动定时器轮询，不订阅 didBecomeActive 刷新逻辑（macOS 12–13 无 SMAppService）
