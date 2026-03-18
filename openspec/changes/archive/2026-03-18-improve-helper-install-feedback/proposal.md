## 为什么

当前 Helper 安装后的状态反馈存在两个体验问题：通过 SMJobBless 安装成功后，状态更新通常需要等待数秒；另外当安装后进入“待生效”并且用户关闭了系统引导弹窗时，设置页缺少持续可见的跳转入口，用户容易丢失操作路径。

在修复过程中进一步发现一个稳定性问题：SMAppService 与 SMJobBless 复用同一 label/mach service 时会产生竞争，导致状态误判、XPC 连接异常以及 SMJobBless 卸载链路频繁回退到 osascript。

## 变更内容

- 优化安装后状态刷新节奏：在安装动作完成后的短时间窗口内，提升状态轮询频率（例如 250ms 或 500ms），尽快把 UI 从“安装中/未安装”更新到最新状态。
- 在“待生效（pending activation）”状态下，在设置页 Helper 状态区域增加可见的“打开系统设置”引导按钮，帮助用户在误关弹窗后仍可继续完成授权。
- 将 SMAppService 与 SMJobBless 的 launchd label/mach service 拆分，避免同名竞争与状态串扰。
- 修正 SMJobBless 自卸载流程，确保 XPC 卸载主路径可落地执行，仅在必要时回退 osascript。
- 保持现有安装流程与权限模型不变，仅增强反馈速度、可恢复性与链路稳定性。

## 功能 (Capabilities)

### 新增功能

- `helper-install-feedback`: 改进安装后状态可见性与待生效场景下的系统设置引导可达性；增强 SMJobBless 卸载收敛与回退策略。

### 修改功能

- `background-switch-guard`: 调整状态监听/轮询策略，并补充待生效时的持续引导入口要求。
- `helper-channel-isolation`（新增）: 为 SMAppService 与 SMJobBless 使用独立 label/mach service，避免互相抢占。

## 影响

- 受影响代码：`StaticRouter/Services/PrivilegedHelperManager.swift`（状态监听、安装/卸载收敛、回退策略）、`StaticRouter/View/SettingsView/SettingsSubViews/GeneralSettings_HelperStateView.swift`（待生效状态下的引导按钮）、`RouteHelper/SelfUninstaller.swift`（自卸载链路）、`Shared/SharedConstant.swift`（双通道常量）、`StaticRouter/Services/RouterService.swift`（按安装方法选择 XPC 通道）。
- 可能新增或调整本地化文案键（按钮标题、辅助说明）。
- 新增 SMAppService 专用 launchd plist（`cn.magicdian.staticrouter.service.plist`）并调整打包清单。
