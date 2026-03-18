## 1. 日志基础设施

- [x] 1.1 在 `PrivilegedHelperManager.swift` 中添加 `os.Logger` 实例（subsystem: `cn.magicdian.staticrouter`, category: `helper-management`），替换后续所有安装/卸载相关的 `print()` 为 Logger 调用
- [x] 1.2 在 `refreshState()` 中添加状态变更日志：检测到 `activeMethod` 或 `isPendingApproval` 变化时记录 INFO 日志

## 2. 移除旧的升级与回退逻辑

- [x] 2.1 删除 `PrivilegedHelperManager.upgrade()` 方法
- [x] 2.2 删除 `PrivilegedHelperManager.installFallback()` 方法
- [x] 2.3 从 `InstallResult` 枚举中移除 `.smAppServiceFailedFallbackAvailable` case
- [x] 2.4 修改 `PrivilegedHelperManager.install()` 方法签名为 `install(method: InstallMethod)`，根据参数执行对应安装路径（SMAppService 或 SMJobBless），不再自动尝试+回退
- [x] 2.5 更新 `RouterService.installHelper()` 签名为 `installHelper(method: InstallMethod)`，透传参数给 PrivilegedHelperManager
- [x] 2.6 删除 `StaticRouteHelperApp.startupCalibration14()` 中的升级弹窗逻辑（`showUpgradePrompt` 状态和 `.alert`）
- [x] 2.7 删除 `GeneralSettings_HelperStateView` 中的 fallback alert 相关代码（`fallbackError` 状态和 `.alert` modifier）
- [x] 2.8 在 `install(method:)` 的入口和出口添加 INFO 级别日志，安装失败时记录 ERROR 日志
- [x] 2.9 在 `uninstall()` 的入口和出口添加 INFO 级别日志

## 3. 安装方式选择对话框（macOS 14+）

- [x] 3.1 创建 `InstallMethodChooserSheet` View 组件：包含方式选择列表（Picker / Radio 样式）、每种方式的描述文本、SMAppService 推荐标记、取消/安装按钮
- [x] 3.2 在 `GeneralSettings_HelperStateView` 中添加 `@AppStorage("preferredInstallMethod")` 存储用户偏好
- [x] 3.3 修改 `installOrUpgradeHelper()` 逻辑：macOS 14+ 弹出 `InstallMethodChooserSheet`；macOS 12–13 直接调用 `installHelper(method: .smJobBless)`
- [x] 3.4 选择器确认后调用 `routerService.installHelper(method:)` 并更新 `@AppStorage` 偏好

## 4. 后台开关状态检测与引导

- [x] 4.1 在 `PrivilegedHelperManager` 中添加 `@available(macOS 14, *)` 的开关状态检查方法 `isBackgroundSwitchOff() -> Bool`，通过读取 `SMAppService.status` 判断 `.requiresApproval`
- [x] 4.2 创建系统设置引导弹窗逻辑：Alert 包含描述信息和"打开系统设置"按钮，按钮调用 `SMAppService.openSystemSettingsLoginItems()`
- [x] 4.3 在安装流程入口（`InstallMethodChooserSheet` 确认时）集成开关检查：若开关关闭，阻断安装并显示引导弹窗
- [x] 4.4 在卸载流程入口（SMAppService 方式卸载时）集成开关检查：若开关关闭，阻断卸载并显示引导弹窗

## 5. 后台开关状态监听

- [x] 5.1 在 `PrivilegedHelperManager` 中添加 `NSApplication.didBecomeActiveNotification` 订阅，回调中调用 `refreshState()`
- [x] 5.2 在 `PrivilegedHelperManager` 中添加 `Timer.publish(every: 10, on: .main, in: .common)` 订阅（仅 macOS 14+），回调中调用 `refreshState()`
- [x] 5.3 确保 `refreshState()` 中状态变化能正确传播到 `RouterService.helperStatus` 和 UI 层

## 6. 通用 StatusBanner 组件

- [x] 6.1 创建 `BannerStyle` 枚举（`.warning`: 浅黄色 + 黄色三角图标, `.info`: 浅蓝色 + 蓝色信息图标）
- [x] 6.2 创建 `StatusBanner` View 组件，接受 `style`、`message`、`actionLabel`、`action` 参数，布局复用现有 HelperNotInstalledBanner 的结构
- [x] 6.3 删除 `HelperNotInstalledBanner`，在 `MainWindow14` 和 `LegacyMainWindow` 中替换为 `StatusBanner`
- [x] 6.4 实现横幅条件逻辑：优先级 1 — helperStatus != .installed 显示 warning；优先级 2 — macOS 14+ 且 activeMethod == .smJobBless 显示 info；否则不显示

## 7. 本地化字符串

- [x] 7.1 在 `en.lproj/Localizable.strings` 中添加新字符串：安装方式选择器标题/描述、StatusBanner 消息、系统设置引导弹窗文本
- [x] 7.2 在 `zh-Hans.lproj/Localizable.strings` 中添加对应中文翻译
- [x] 7.3 移除不再使用的旧字符串（upgrade alert、fallback alert 相关）

## 8. 验证与清理

- [x] 8.1 确认 macOS 12–13 路径不受影响：无选择对话框、无开关监听、无 info banner
- [x] 8.2 确认编译通过，无对已删除方法/属性的引用
- [x] 8.3 清理 `StaticRouteHelperApp` 中的 `showUpgradePrompt` 状态属性和相关 alert modifier
