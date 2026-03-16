## ADDED Requirements

### Requirement: 创建路由分组
用户 SHALL 能够通过 Sidebar 底部的 "+" 按钮创建新的路由分组。创建时 SHALL 要求输入分组名称，名称不能为空。

#### Scenario: 创建新分组
- **WHEN** 用户点击 Sidebar 底部 "+" 按钮并输入 "Office VPN"
- **THEN** 系统在 Sidebar 的 GROUPS section 中显示新分组 "Office VPN"

#### Scenario: 创建空名称分组
- **WHEN** 用户尝试创建名称为空的分组
- **THEN** 系统拒绝创建，保存按钮为禁用状态

### Requirement: 编辑路由分组
用户 SHALL 能够编辑已有分组的名称和图标。编辑操作通过右键上下文菜单或双击分组名称触发。

#### Scenario: 重命名分组
- **WHEN** 用户右键点击 "Office VPN" 分组，选择"重命名"，将名称改为 "Corp VPN"
- **THEN** Sidebar 中显示更新后的名称 "Corp VPN"，该分组下的路由关联不变

### Requirement: 删除路由分组
用户 SHALL 能够通过右键上下文菜单删除路由分组。删除分组 SHALL 仅解除该分组与路由规则的关联，不删除路由规则本身。删除前 SHALL 显示确认对话框。

#### Scenario: 删除包含路由的分组
- **WHEN** 用户删除 "Office VPN" 分组（包含 3 条路由，其中 1 条同时属于 "Home VPN"）
- **THEN** 系统显示确认对话框，确认后删除分组，3 条路由仍然存在于 SwiftData 中，属于 "Home VPN" 的那条路由的 groups 不再包含 "Office VPN"

#### Scenario: 取消删除分组
- **WHEN** 用户在确认对话框中点击"取消"
- **THEN** 分组保留不变

### Requirement: 分组排序
用户 SHALL 能够通过拖拽 Sidebar 中的分组条目来调整分组的显示顺序。拖拽后 SHALL 更新所有受影响分组的 `sortOrder` 值并持久化。

#### Scenario: 拖拽调整分组顺序
- **WHEN** 用户将 "Home VPN" 拖拽到 "Office VPN" 上方
- **THEN** Sidebar 中 "Home VPN" 显示在 "Office VPN" 上方，此顺序在应用重启后保持

### Requirement: 路由的分组关联管理
在路由编辑 Sheet 中，用户 SHALL 能够通过复选框列表选择该路由所属的分组（支持选择零个或多个分组）。

#### Scenario: 将路由关联到多个分组
- **WHEN** 用户编辑路由 "192.168.4.0/24"，勾选 "Office VPN" 和 "Home VPN"
- **THEN** 该路由的 `groups` 包含这两个分组，在两个分组视图中均可见

#### Scenario: 路由不关联任何分组
- **WHEN** 用户创建路由但不勾选任何分组
- **THEN** 路由仍然保存成功，仅在 "All Routes" 视图中可见
