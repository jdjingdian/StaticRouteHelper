## ADDED Requirements

### Requirement: 安装后短时快速状态刷新
系统必须在 Helper 安装成功后进入一个短时快速刷新窗口，以更快反映最终安装状态。快速窗口期间系统必须以不高于 500ms 的间隔轮询刷新状态，并在窗口结束后恢复到常规低频监听策略。

#### Scenario: SMJobBless 安装后快速更新状态
- **WHEN** 用户通过 SMJobBless 完成安装并关闭系统授权对话框
- **THEN** 系统在短时窗口内以高于常规频率刷新状态，并在约 3 秒内将界面更新为最新安装状态（已安装或其他最终状态）

#### Scenario: 快速窗口结束后恢复常规策略
- **WHEN** 安装后的快速刷新窗口结束
- **THEN** 系统恢复到常规状态监听频率，不继续长期高频轮询

### Requirement: 待生效状态下设置页持续引导入口
当 Helper 处于待生效状态时，设置页必须显示一个可见的“打开系统设置”入口。用户点击该入口后，系统必须跳转到登录项与扩展设置页面，且不依赖一次性弹窗是否出现或是否被取消。

#### Scenario: 用户取消弹窗后仍可继续操作
- **WHEN** 安装后出现引导弹窗且用户点击取消，随后 Helper 仍处于待生效状态
- **THEN** 设置页状态区域继续显示“打开系统设置”入口，用户可再次发起跳转

#### Scenario: 用户通过设置页入口跳转系统设置
- **WHEN** Helper 处于待生效状态且用户点击设置页中的“打开系统设置”入口
- **THEN** 系统调用登录项设置跳转能力并打开对应系统设置页面

### Requirement: SMJobBless 与 SMAppService 服务通道隔离
系统必须为 SMJobBless 与 SMAppService 使用不同的 launchd label 与 mach service，避免同名服务竞争导致状态误判与连接异常。

#### Scenario: SMJobBless 安装后状态不被 SMAppService 抢占
- **WHEN** 用户安装 SMJobBless helper
- **THEN** 系统将 `activeMethod` 识别为 `smJobBless`，且不会因 SMAppService 后台开关状态变化被改写为 `smAppService`

#### Scenario: 路由命令按安装方法选择 XPC 通道
- **WHEN** 当前安装方法为 `smJobBless` 或 `smAppService`
- **THEN** 系统使用对应方法的 mach service 发送路由写入请求，不跨通道复用同一 XPC 客户端

### Requirement: SMJobBless 卸载优先走 XPC 主路径
系统应优先通过 XPC 向 helper 发送卸载请求。若请求失败或在收敛窗口内未观察到卸载落地，再回退到 osascript 兜底。

#### Scenario: XPC 卸载成功并收敛
- **WHEN** helper 收到卸载请求并完成自删除
- **THEN** 系统在收敛窗口内观察到 helper artifacts 消失，并记录“state settled after XPC request”

#### Scenario: XPC 卸载失败或未收敛时回退
- **WHEN** XPC 请求超时/失败，或收敛窗口结束时 helper artifacts 仍存在
- **THEN** 系统执行 osascript 强制卸载作为兜底路径

### Requirement: 安装正常但通信失败时提供可恢复反馈
当 helper 安装状态显示为可用但路由请求出现 XPC 通信失败时，系统必须提供面向恢复的交互引导，而不是仅展示底层错误描述。

#### Scenario: SMAppService 通道异常触发恢复引导
- **WHEN** helper 状态为 `installed` 且活动安装方法为 `smAppService`，用户执行路由写入操作收到 XPC 通信失败
- **THEN** 系统触发恢复弹窗流程，向用户提供可执行的修复路径

#### Scenario: 非 SMAppService 或前置条件不满足时不触发自动重装弹窗
- **WHEN** XPC 失败发生在 `smJobBless` 路径，或系统判断为后台开关关闭导致的待授权场景
- **THEN** 系统不展示自动重装弹窗，维持原有错误反馈与引导路径
