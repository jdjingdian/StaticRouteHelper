## ADDED Requirements

### Requirement: 路由激活操作
用户 SHALL 能够通过路由列表中每行的 Toggle 开关激活路由。激活操作 SHALL 通过 XPC 调用 Helper 执行 `route add` 命令将路由添加到系统路由表。激活成功后，RouteRule 的 `isActive` SHALL 更新为 `true`。

#### Scenario: 激活一条路由
- **WHEN** 用户将 "192.168.4.0/24 → utun3" 路由的 Toggle 从关闭切换为开启
- **THEN** 系统通过 Helper 执行 `route add -net 192.168.4.0 -netmask 255.255.255.0 -iface utun3`，成功后 isActive 更新为 true，Toggle 显示为开启状态

#### Scenario: 激活路由失败
- **WHEN** 用户尝试激活一条路由，但 Helper 返回错误（如路由已存在、网关不可达）
- **THEN** Toggle 恢复为关闭状态，isActive 保持 false，系统显示错误提示（Alert 或内联错误信息）

### Requirement: 路由停用操作
用户 SHALL 能够通过 Toggle 开关停用已激活的路由。停用操作 SHALL 通过 XPC 调用 Helper 执行 `route delete` 命令从系统路由表中删除路由。停用成功后，RouteRule 的 `isActive` SHALL 更新为 `false`。

#### Scenario: 停用一条路由
- **WHEN** 用户将已激活路由的 Toggle 从开启切换为关闭
- **THEN** 系统通过 Helper 执行 `route delete -net 192.168.4.0 -netmask 255.255.255.0 -iface utun3`，成功后 isActive 更新为 false

#### Scenario: 停用路由失败
- **WHEN** 用户尝试停用路由，但操作失败（如路由已被其他方式删除）
- **THEN** 系统显示错误提示，并刷新 isActive 状态以反映实际系统状态

### Requirement: Helper 未安装时禁用激活操作
当 Privileged Helper 未安装或状态异常时，所有路由的 Toggle 开关 SHALL 处于禁用状态，并显示提示（如 tooltip 或灰色 + 提示文字）告知用户需要先安装 Helper。

#### Scenario: Helper 未安装时尝试操作
- **WHEN** Helper 未安装，用户查看路由列表
- **THEN** 所有 Toggle 开关显示为灰色禁用状态

### Requirement: 应用退出时的路由状态
应用退出时 SHALL 保持当前系统路由表状态不变（不自动清理已激活的路由）。应用重新启动时，SHALL 根据实际系统路由表状态校准 RouteRule 的 `isActive` 标记。

#### Scenario: 应用退出后路由保持
- **WHEN** 用户在 2 条路由激活状态下退出应用
- **THEN** 系统路由表中这 2 条路由继续生效

#### Scenario: 应用重启后状态校准
- **WHEN** 应用重新启动，检测到系统路由表中存在 1 条之前激活的路由（另 1 条已被外部操作删除）
- **THEN** 第 1 条路由的 isActive 校准为 true，第 2 条校准为 false

### Requirement: 批量激活/停用（后续可选）
当前版本仅支持逐条 Toggle 操作。批量操作（如"激活分组内所有路由"）作为后续增强，不在本次范围内。

#### Scenario: 用户逐条操作路由
- **WHEN** 用户需要激活分组中的 5 条路由
- **THEN** 用户逐一切换每条路由的 Toggle
