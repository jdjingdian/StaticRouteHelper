## ADDED Requirements

### Requirement: 安装正常但通信失败时提供可恢复反馈
当 helper 安装状态显示为可用但路由请求出现 XPC 通信失败时，系统必须提供面向恢复的交互引导，而不是仅展示底层错误描述。

#### Scenario: SMAppService 通道异常触发恢复引导
- **WHEN** helper 状态为 `installed` 且活动安装方法为 `smAppService`，用户执行路由写入操作收到 XPC 通信失败
- **THEN** 系统触发恢复弹窗流程，向用户提供可执行的修复路径

#### Scenario: 非 SMAppService 或前置条件不满足时不触发自动重装弹窗
- **WHEN** XPC 失败发生在 `smJobBless` 路径，或系统判断为后台开关关闭导致的待授权场景
- **THEN** 系统不展示自动重装弹窗，维持原有错误反馈与引导路径
