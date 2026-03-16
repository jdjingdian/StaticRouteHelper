# Spec: route-group-assign

## Requirements

### Requirement: 用户路由 SF Symbol 标记
`SystemRouteTableView` 的"目标"列中，属于用户添加路由的行 SHALL 显示 `person.fill` SF Symbol 图标（accentColor 着色，small imageScale），替代原有的 6×6 Circle 圆点。

#### Scenario: 用户路由显示 SF Symbol
- **WHEN** 系统路由表中存在与 SwiftData `RouteRule` 匹配的条目（destination + gateway 相同）
- **THEN** 该行"目标"列在文字左侧显示 `person.fill` 图标，并保持行背景 accent 色半透明高亮

#### Scenario: 系统路由不显示图标
- **WHEN** 系统路由表条目与任何 `RouteRule` 不匹配
- **THEN** 该行"目标"列不显示任何图标，背景为透明

### Requirement: AddGroupSheet 图标选择器自适应布局
`AddGroupSheet` 中的图标选择器 SHALL 使用 `HStack` 排列（替代固定列宽 `LazyVGrid`），确保在宽度内不溢出且图标完整显示。

#### Scenario: 图标在 sheet 宽度内完整显示
- **WHEN** 用户打开"添加分组" sheet
- **THEN** 所有图标选项均在同一行内完整显示，无截断或溢出

#### Scenario: 选中图标高亮反馈
- **WHEN** 用户点击某个图标
- **THEN** 该图标显示 accentColor 背景高亮，其他图标高亮清除

### Requirement: 右键菜单"管理分组"入口
`RouteListView` 右键上下文菜单 SHALL 包含"管理分组…"选项，点击后打开 `AssignGroupsSheet` 弹窗。

#### Scenario: 右键菜单出现"管理分组"选项
- **WHEN** 用户在路由列表中右键点击某条路由
- **THEN** 上下文菜单显示"管理分组…"选项（位于"编辑"和"删除"之间）

#### Scenario: 点击"管理分组"打开专用弹窗
- **WHEN** 用户选择右键菜单中的"管理分组…"
- **THEN** 打开 `AssignGroupsSheet`，列出所有分组并显示当前勾选状态

### Requirement: AssignGroupsSheet 分组多选弹窗
`AssignGroupsSheet` SHALL 显示所有 `RouteGroup` 的列表，每项包含勾选框、分组图标和名称；用户可多选/取消，保存后更新 `RouteRule.groups` 和对应 `RouteGroup.routes` 的双向关联。

#### Scenario: 当前分组预选中
- **WHEN** `AssignGroupsSheet` 打开
- **THEN** 路由当前已关联的分组勾选框为选中状态

#### Scenario: 保存更新双向关联
- **WHEN** 用户修改勾选状态后点击"保存"
- **THEN** `RouteRule.groups` 更新为新选中的分组列表，对应 `RouteGroup.routes` 同步更新，弹窗关闭

#### Scenario: 无分组时显示提示
- **WHEN** `AssignGroupsSheet` 打开但系统中没有任何分组
- **THEN** 弹窗显示"尚无分组，请先在侧栏创建分组"提示文字，无勾选列表

#### Scenario: 取消不保存
- **WHEN** 用户点击"取消"按钮
- **THEN** 弹窗关闭，路由分组关联不变
