## ADDED Requirements

### Requirement: 添加路由规则
用户 SHALL 能够通过路由列表视图中的 "添加路由" 按钮打开 Sheet 表单，输入路由信息并保存。

Sheet 表单 SHALL 包含以下输入项：
- 网络地址（IPv4 文本输入）
- 前缀长度（数字输入或下拉选择，范围 0-32）
- 路由方式（分段选择器：网关 IP / 网络接口）
- 网关地址或接口名称（根据路由方式切换）
- 所属分组（多选复选框列表，列出所有已有分组）

表单 SHALL 在前缀长度下方自动显示对应的子网掩码（只读，如 "/24 = 255.255.255.0"）。

#### Scenario: 添加使用 IP 网关的路由
- **WHEN** 用户点击"添加路由"，输入网络地址 "192.168.5.0"，前缀长度 24，选择"网关 IP"，输入 "10.0.0.1"，勾选 "Office VPN" 分组，点击"保存"
- **THEN** 系统创建新路由规则（isActive 为 false），在 "All Routes" 和 "Office VPN" 视图中可见

#### Scenario: 添加使用网络接口的路由
- **WHEN** 用户选择"网络接口"方式，输入 "utun3"
- **THEN** 系统创建路由规则，`gatewayType` 为 `.interface`，`gateway` 为 "utun3"

#### Scenario: 从分组视图中添加路由
- **WHEN** 用户在 "Office VPN" 分组视图中点击"添加路由"
- **THEN** Sheet 表单中 "Office VPN" 复选框默认已勾选

### Requirement: 编辑路由规则
用户 SHALL 能够编辑已有的路由规则。编辑操作通过双击路由行或右键上下文菜单中的"编辑"选项触发，打开与添加相同的 Sheet 表单，预填充当前值。

#### Scenario: 编辑路由规则
- **WHEN** 用户双击 "192.168.4.0/24" 路由行
- **THEN** 打开 Sheet 表单，预填充该路由的当前网络地址、前缀长度、网关信息和分组关联

#### Scenario: 编辑路由后保存
- **WHEN** 用户将网关从 "10.0.0.1" 修改为 "10.0.0.2"，点击"保存"
- **THEN** 路由规则更新，若该路由当前 isActive 为 true，系统 SHALL 先删除旧路由再添加新路由（即自动重新激活）

### Requirement: 删除路由规则
用户 SHALL 能够删除路由规则。删除操作通过以下方式触发：
- 路由行上的右键上下文菜单中的"删除"选项
- 选中路由行后按 Delete/Backspace 键
- 路由行上的左滑手势（如果适用）

删除前 SHALL 显示确认对话框。若路由当前 isActive 为 true，系统 SHALL 先从系统路由表中删除该路由，再从 SwiftData 中删除。

#### Scenario: 删除未激活的路由
- **WHEN** 用户删除一条 isActive 为 false 的路由并确认
- **THEN** 路由从 SwiftData 中删除，从所有关联分组中消失

#### Scenario: 删除已激活的路由
- **WHEN** 用户删除一条 isActive 为 true 的路由并确认
- **THEN** 系统先通过 Helper 从系统路由表中删除该路由，再从 SwiftData 中删除

#### Scenario: 取消删除
- **WHEN** 用户在确认对话框中点击"取消"
- **THEN** 路由保留不变

### Requirement: 路由列表显示
路由列表 SHALL 以表格形式显示路由规则，每行包含：
- 目标网络（CIDR 格式，如 "192.168.4.0/24"）
- 路由方式标识（网关 IP 或接口名称）
- 激活状态 Toggle 开关
- 所属分组标签（在 All Routes 视图中显示）

列表顶部 SHALL 显示当前视图标题和路由统计信息（如 "3 条路由 · 1 条已激活"）。

#### Scenario: All Routes 视图显示所有路由
- **WHEN** 用户选中 Sidebar 的 "All Routes"
- **THEN** 右侧列表显示所有路由规则（不重复），每条路由显示其关联的分组标签

#### Scenario: Group 视图显示过滤路由
- **WHEN** 用户选中 "Office VPN" 分组
- **THEN** 右侧列表仅显示属于 "Office VPN" 的路由，不显示分组标签列

### Requirement: 输入验证
路由编辑 Sheet SHALL 对用户输入进行实时验证：
- 网络地址 SHALL 符合 IPv4 格式（四段点分十进制，每段 0-255）
- 前缀长度 SHALL 在 0-32 范围内
- 网关地址（IP 模式）SHALL 符合 IPv4 格式
- 接口名称（接口模式）SHALL 非空
- 验证失败的字段 SHALL 显示红色边框和错误提示文字
- 存在验证错误时，"保存"按钮 SHALL 处于禁用状态

#### Scenario: 输入无效 IP 地址
- **WHEN** 用户在网络地址字段输入 "999.0.0.1"
- **THEN** 字段显示红色边框，下方显示错误提示（如 "无效的 IPv4 地址"），保存按钮禁用

#### Scenario: 所有字段有效
- **WHEN** 用户填写的所有字段均通过验证
- **THEN** 保存按钮启用，无错误提示显示

### Requirement: 路由行上下文菜单
路由列表中的每行 SHALL 支持右键上下文菜单，包含以下选项：
- "编辑"：打开编辑 Sheet
- "删除"：触发删除确认
- "复制路由信息"：将路由信息（如 "route add -net 192.168.4.0 -netmask 255.255.255.0 -gateway 10.0.0.1"）复制到剪贴板

#### Scenario: 复制路由信息
- **WHEN** 用户右键点击路由，选择"复制路由信息"
- **THEN** 系统将该路由对应的 route 命令字符串复制到系统剪贴板
