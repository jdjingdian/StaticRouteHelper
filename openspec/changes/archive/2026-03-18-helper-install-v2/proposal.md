## Why

当前 macOS 14+ 上的 Helper 安装策略基于一个错误假设：SMJobBless 可以绕过"后台运行"开关限制，因此被作为 SMAppService 的自动回退方案。实际测试发现两种方式都受该开关约束，导致回退机制失效。同时，现有架构缺乏对系统设置开关状态的感知能力，用户在开关关闭时尝试安装/卸载会遇到不明确的失败。2.1.0 版本需要重新设计 Helper 安装流程，将两种方式平等呈现给用户选择，并加入开关状态监听和引导机制。

## What Changes

- **macOS 12–13**：保持现有行为不变，仅提供 SMJobBless 安装方式
- **macOS 14+ 安装方式选择器**：用户点击安装时弹出对话框，可选择 SMAppService（推荐）或 SMJobBless，不再自动尝试 SMAppService 后回退
- **移除原子升级路径**：删除 `upgrade()` 方法和启动时自动升级弹窗，切换安装方式必须先卸载再重新选择安装
- **通用 StatusBanner 组件**：替换现有 `HelperNotInstalledBanner`，支持 `.warning`（浅黄色，未安装提示）和 `.info`（浅蓝色，SMJobBless 可升级提示）两种样式，统一 UI 设计风格
- **后台开关状态监听**：通过 `NSApplication.didBecomeActiveNotification` + 低频定时器（10–15s）混合方案轮询 `SMAppService.status`，实时感知用户在系统设置中的开关变化
- **安装/卸载前开关检查**：在执行 SMAppService 相关操作前检测开关状态，若关闭则弹窗引导用户跳转系统设置（Login Items & Extensions）
- **os.Logger 结构化日志**：在 Helper 安装/卸载/状态检测的关键入口添加 INFO 级别日志，替代现有 `print()` 调试输出
- **用户偏好持久化**：通过 UserDefaults 记录用户选择的安装方式偏好（仅 macOS 14+），供卸载后重新安装时预选

## Capabilities

### New Capabilities
- `install-method-chooser`: macOS 14+ 安装方式选择对话框，让用户在 SMAppService 和 SMJobBless 之间选择
- `background-switch-guard`: 后台运行开关状态检测、监听、以及引导用户跳转系统设置的弹窗机制
- `status-banner`: 通用状态横幅组件，替代现有 HelperNotInstalledBanner，支持 warning/info 样式
- `helper-install-logging`: 使用 os.Logger 的结构化日志，覆盖 Helper 安装/卸载/状态变更的关键路径

### Modified Capabilities
- `router-service`: PrivilegedHelperManager 移除 upgrade() 方法和自动回退逻辑，install() 改为接受用户选择的方式参数，新增开关状态监听集成

## Impact

- **PrivilegedHelperManager.swift**: 重构核心文件，移除 `upgrade()`、`installFallback()`、自动回退逻辑；`install()` 签名变更为接受 `InstallMethod` 参数；新增开关状态监听逻辑
- **InstallMethod.swift**: `InstallResult` 枚举移除 `.smAppServiceFailedFallbackAvailable`
- **RouterService.swift**: `installHelper()` 签名变更，传递用户选择的安装方式
- **StaticRouteHelperApp.swift**: 移除启动时升级弹窗逻辑
- **MainWindow.swift**: 替换 `HelperNotInstalledBanner` 为通用 `StatusBanner`
- **GeneralSettings_HelperStateView.swift**: 移除回退确认弹窗，集成安装方式选择器
- **GeneralSettingsView.swift**: 卸载流程可能需要开关检查
- **Localizable.strings (en/zh-Hans)**: 新增选择器、横幅、系统设置引导相关本地化字符串
- **依赖**: 无新增外部依赖；os.Logger 为系统框架
