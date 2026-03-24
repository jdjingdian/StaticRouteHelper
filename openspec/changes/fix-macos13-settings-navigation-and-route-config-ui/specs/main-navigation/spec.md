## MODIFIED Requirements

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
