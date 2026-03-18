## ADDED Requirements

### Requirement: 待生效状态识别
在 macOS 14+ 上，当 `SMAppService.daemon(...).status` 为 `.requiresApproval` 且 Helper 已完成安装时，系统 SHALL 将 Helper 状态识别为“待生效”（`pendingActivation`），而不是“未安装”。

#### Scenario: 安装成功后进入待生效
- **WHEN** 用户点击安装且安装流程返回成功，但后台运行开关处于关闭状态（`.requiresApproval`）
- **THEN** 系统将 `helperStatus` 标记为 `pendingActivation`，并保留 `activeMethod == .smAppService`

#### Scenario: App 启动时识别历史待生效
- **WHEN** App 启动时检测到 Helper 已存在且 `SMAppService.status == .requiresApproval`
- **THEN** 系统显示为 `pendingActivation`，不显示为 `notInstalled`

#### Scenario: 后台开关开启后转为已安装
- **WHEN** 用户开启后台运行开关，使 `SMAppService.status` 从 `.requiresApproval` 变为 `.enabled`
- **THEN** 系统将 `helperStatus` 从 `pendingActivation` 更新为 `installed`

### Requirement: 待生效状态下的操作可用性
当 Helper 处于待生效状态时，系统 SHALL 允许用户执行卸载操作，避免用户被卡在不可恢复状态。

#### Scenario: 待生效状态允许点击卸载
- **WHEN** 设置页显示当前状态为 `pendingActivation`
- **THEN** 卸载入口可用，用户可直接触发卸载流程
