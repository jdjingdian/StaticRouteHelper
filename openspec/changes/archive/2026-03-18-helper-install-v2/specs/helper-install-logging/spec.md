## ADDED Requirements

### Requirement: 结构化日志框架
App 端 SHALL 使用 `os.Logger` 进行结构化日志输出，subsystem 为 `cn.magicdian.staticrouter`。Helper 安装管理相关日志 SHALL 使用 category `helper-management`。

#### Scenario: Logger 实例化
- **WHEN** `PrivilegedHelperManager` 初始化
- **THEN** 内部持有一个 `Logger(subsystem: "cn.magicdian.staticrouter", category: "helper-management")` 实例

### Requirement: 安装流程日志
安装操作的入口和出口 SHALL 记录 INFO 级别日志，包含操作类型和结果。

#### Scenario: SMAppService 安装成功
- **WHEN** 通过 SMAppService 安装 Helper 成功
- **THEN** 日志记录包含："Installing helper via SMAppService" (入口) 和 "Helper installed successfully via SMAppService" (出口)

#### Scenario: SMJobBless 安装成功
- **WHEN** 通过 SMJobBless 安装 Helper 成功
- **THEN** 日志记录包含："Installing helper via SMJobBless" (入口) 和 "Helper installed successfully via SMJobBless" (出口)

#### Scenario: 安装失败
- **WHEN** 安装操作失败（任一方式）
- **THEN** 日志记录 ERROR 级别信息，包含失败原因

### Requirement: 卸载流程日志
卸载操作的入口和出口 SHALL 记录 INFO 级别日志。

#### Scenario: SMAppService 卸载
- **WHEN** 通过 SMAppService 卸载 Helper
- **THEN** 日志记录 "Uninstalling helper (SMAppService)" (入口) 和操作结果 (出口)

#### Scenario: SMJobBless 卸载
- **WHEN** 通过 XPC 卸载 SMJobBless Helper
- **THEN** 日志记录 "Uninstalling helper (SMJobBless) via XPC" (入口) 和操作结果 (出口)

### Requirement: 状态变更日志
`refreshState()` 检测到状态变化时 SHALL 记录 INFO 级别日志。

#### Scenario: 状态从未安装变为已安装
- **WHEN** `refreshState()` 检测到 `activeMethod` 从 `nil` 变为 `.smAppService`
- **THEN** 日志记录 "Helper state changed: nil → smAppService"

#### Scenario: 开关状态变化
- **WHEN** `refreshState()` 检测到 `isPendingApproval` 从 `false` 变为 `true`
- **THEN** 日志记录 "Background switch state changed: pending approval detected"
