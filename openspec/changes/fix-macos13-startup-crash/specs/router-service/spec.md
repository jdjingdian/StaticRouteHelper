## ADDED Requirements

### 需求:RouterService 初始化必须容忍监听器降级
`RouterService` 在初始化过程中必须容忍 `HelperToolMonitor` 启动失败或部分失败；无论监听器是否可用，`RouterService` 都必须完成初始化并对外提供可用实例。

#### 场景:监听器全部失败时完成初始化
- **当** `HelperToolMonitor.start` 返回“无可用监听源”
- **那么** `RouterService.init()` 必须完成，且应用主界面可正常进入

#### 场景:监听器部分成功时完成初始化
- **当** `HelperToolMonitor.start` 仅创建了部分监听源
- **那么** `RouterService` 必须按部分可用状态继续运行，不得抛出致命错误

### 需求:监听不可用时必须启用状态刷新兜底
当监听器不可用时，系统必须通过低频主动刷新保持 helper 安装状态可更新，避免状态长期陈旧。

#### 场景:初始化后进入轮询兜底
- **当** `RouterService` 检测到监听不可用
- **那么** 系统必须启动低频刷新任务，周期性执行状态刷新并更新 `helperStatus`

#### 场景:应用恢复激活时即时刷新
- **当** 应用从后台回到前台或重新激活
- **那么** 系统必须立即触发一次 helper 状态刷新，而不是等待下一次轮询周期
