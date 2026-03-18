## 为什么

在通过 SMAppService 安装 helper 的场景下，即使系统后台开关已开启，helper 与主程序仍可能因版本/注册状态不一致导致 XPC 不可达，用户会看到通信错误并且当前缺少明确的恢复入口。该问题在 ad-hoc 迭代更新时更容易出现，需要提供就地自愈路径而不是要求用户手动排障。

## 变更内容

- 当检测到 helper 当前安装方式为 SMAppService，且 XPC 请求失败时，新增恢复提示弹窗。
- 弹窗提供两个选项：`取消` 与 `自动重装`。
- `自动重装` 触发标准恢复流程：先卸载当前 helper 注册，再重新安装 helper。
- 在 UI 语义上将 `自动重装` 作为推荐操作（主按钮/默认动作），降低用户决策成本。
- 仅在满足前置条件时显示该弹窗：SMAppService 路径、XPC 不可达、且后台开关并非关闭导致的待授权场景。

## 功能 (Capabilities)

### 新增功能
- `helper-reinstall-recovery`: 当 SMAppService 路径出现 XPC 通信不可达时，向用户提供可执行的自动重装恢复流程。

### 修改功能
- `helper-install-feedback`: 扩展错误反馈策略，在安装状态正常但通信失败时补充可恢复交互，而不只展示底层错误文本。

## 影响

- 受影响代码：`StaticRouter/Services/RouterService.swift`（XPC 错误识别与恢复触发）、`StaticRouter/View/RouteListView.swift`、`StaticRouter/View/LegacyRouteListView.swift`（新增恢复弹窗展示与动作编排）、`StaticRouter/Services/PrivilegedHelperManager.swift`（复用卸载+安装链路作为自动重装实现）。
- 受影响文案：`Resources/Locale/zh-Hans.lproj/Localizable.strings` 与 `Resources/Locale/en.lproj/Localizable.strings` 新增恢复弹窗标题、说明、按钮文案。
- 对既有安装协议无破坏性变更；主要增加失败场景下的交互与恢复路径。
