## ADDED Requirements

### Requirement: NavigationSplitView 两栏主布局
应用主窗口 SHALL 使用 NavigationSplitView 实现两栏布局，左侧为 Sidebar，右侧为 Detail 内容区。

#### Scenario: 应用启动显示主界面
- **WHEN** 用户启动应用
- **THEN** 显示两栏布局，左侧 Sidebar 包含 "All Routes"、GROUPS section、SYSTEM section，右侧默认显示 "All Routes" 内容

### Requirement: Sidebar 结构
Sidebar SHALL 包含以下固定结构：
1. "All Routes" 条目（始终位于顶部，显示所有路由规则的总览）
2. "GROUPS" Section（显示用户创建的所有路由分组，按 sortOrder 排序）
3. "SYSTEM" Section（包含 "Route Table" 条目，用于查看系统路由表）

每个 Sidebar 条目 SHALL 显示名称和关联路由数量的角标（badge）。

#### Scenario: Sidebar 显示带角标的分组
- **WHEN** Sidebar 中有 "Office VPN" 分组，包含 3 条路由
- **THEN** "Office VPN" 条目右侧显示角标 "3"

#### Scenario: All Routes 角标显示去重数量
- **WHEN** 系统中共有 5 条不重复的路由规则
- **THEN** "All Routes" 条目右侧显示角标 "5"（不因多对多关联重复计数）

### Requirement: Sidebar 导航
点击 Sidebar 条目 SHALL 在右侧 Detail 区域显示对应内容：
- "All Routes"：显示所有路由规则列表
- Group 条目：显示该分组关联的路由规则列表
- "Route Table"：显示系统路由表

#### Scenario: 切换 Sidebar 选中项
- **WHEN** 用户从 "All Routes" 点击切换到 "Office VPN"
- **THEN** 右侧内容区域从显示所有路由变为仅显示 "Office VPN" 分组下的路由

### Requirement: 窗口自适应布局
主窗口 SHALL 支持自适应布局：
- 默认窗口大小约 800×600
- 窗口宽度充足时，Sidebar 和 Detail 并排显示
- 窗口宽度不足时，Sidebar SHALL 可通过工具栏按钮或手势折叠为 overlay 模式
- 利用 NavigationSplitView 的原生 `columnVisibility` 机制实现

#### Scenario: 窗口缩小时 Sidebar 折叠
- **WHEN** 用户将窗口宽度缩小到 Sidebar 无法并排显示的程度
- **THEN** Sidebar 自动折叠，用户可通过工具栏按钮重新显示

#### Scenario: 窗口恢复宽度时 Sidebar 展开
- **WHEN** 用户将窗口宽度恢复
- **THEN** Sidebar 自动展开为并排显示

### Requirement: Sidebar 底部工具栏
Sidebar 底部 SHALL 显示工具栏，包含：
- "+" 按钮：创建新的路由分组
- 设置按钮（齿轮图标）：打开应用设置窗口

设置按钮 SHALL 通过统一的设置导航策略执行，确保 macOS 12–14+ 均可打开设置窗口。该策略必须包含版本感知和失败回退（例如首选现代入口，失败后尝试 selector 回退链路）。

#### Scenario: 点击添加分组按钮
- **WHEN** 用户点击 Sidebar 底部的 "+" 按钮
- **THEN** 弹出分组创建界面（输入名称的弹窗或 Sheet）

#### Scenario: macOS 14+ 点击设置按钮
- **WHEN** 用户在 macOS 14+ 点击齿轮图标
- **THEN** 应用设置窗口被打开，且当前窗口保持可交互

#### Scenario: macOS 13 点击设置按钮
- **WHEN** 用户在 macOS 13 点击齿轮图标
- **THEN** 应用通过回退策略成功打开设置窗口，不得出现无响应

#### Scenario: 首选设置入口不可用时回退
- **WHEN** 当前首选设置入口调用失败或不可用
- **THEN** 系统自动尝试后续回退入口，直到设置窗口成功打开或记录失败日志

### Requirement: Helper 未安装横幅提示
当 Privileged Helper 未安装时，主界面顶部 SHALL 显示醒目的横幅提示，告知用户需要安装 Helper 才能执行路由操作，并提供跳转到设置页面的按钮。

#### Scenario: Helper 未安装时显示横幅
- **WHEN** 应用启动且 Helper 未安装或版本不兼容
- **THEN** 主界面 Detail 区域顶部显示黄色/橙色横幅："需要安装路由助手才能管理路由。[前往设置]"

#### Scenario: Helper 已安装时不显示横幅
- **WHEN** 应用启动且 Helper 已正确安装
- **THEN** 不显示横幅提示
