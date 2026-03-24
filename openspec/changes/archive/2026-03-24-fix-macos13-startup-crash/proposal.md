## 为什么

macOS 13 上应用启动会在主线程必现崩溃，崩溃栈指向 `HelperToolMonitor.start(changeOccurred:)` 内部的 `DispatchSource` 创建流程。当前实现在 `open(..., O_EVTONLY)` 失败时仍继续创建 `DispatchSource`，触发 `EXC_BREAKPOINT (SIGTRAP)`，导致应用无法启动。

## 变更内容

- 修复 `HelperToolMonitor` 目录监听初始化流程：`open` 失败时不再创建 `DispatchSource`，改为记录失败并安全跳过该监控项。
- 为目录监听增加可观测的降级行为：当全部监听源不可用时，`RouterService` 仍可完成初始化，Helper 状态通过一次主动刷新或低频兜底刷新维持可用。
- 强化生命周期管理：仅对已创建的 source 执行 `resume/cancel`，防止重复启动、重复关闭或非法文件描述符路径。
- 增加 macOS 13 回归验证场景，覆盖“目录不可监听/权限受限/路径不存在”三类启动条件。

## 功能 (Capabilities)

### 新增功能
- `helper-monitor-stability`: 规范 Helper 安装状态监听在异常文件系统条件下的容错行为，确保启动阶段不崩溃并提供可预期的降级策略。

### 修改功能
- `router-service`: `RouterService` 初始化阶段在监听器部分失败时不应崩溃，且应保持 helper 状态可读与后续可恢复。

## 影响

- 受影响代码：
  - `StaticRouter/Components/HelperToolMonitor.swift`
  - `StaticRouter/Services/RouterService.swift`
- 受影响行为：
  - 启动期 helper 状态监控初始化流程
  - macOS 13 上首帧稳定性与安装状态展示一致性
- 测试与验证：
  - 新增/更新单元测试（监听源创建失败路径）
  - 手工回归：macOS 13.4 启动、安装/卸载 helper 后状态刷新
