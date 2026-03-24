## MODIFIED Requirements

### Requirement: 添加路由规则
用户 SHALL 能够通过路由列表视图中的 "添加路由" 按钮打开 Sheet 表单，输入路由信息并保存。

在 macOS 14+ 上，Sheet 表单 SHALL 包含以下输入项：
- 网络地址（IPv4 文本输入）
- 前缀长度（数字输入或下拉选择，范围 0-32）
- 路由方式（分段选择器：网关 IP / 网络接口）
- 网关地址或接口名称（根据路由方式切换）
- 所属分组（多选分组标签卡片，列出所有已有分组）

在 macOS 12–13 上，Sheet 表单 SHALL 包含除分组多选以外的所有字段，分组选择区域不显示。

添加路由表单在所有支持版本上 SHALL 对齐 `design/STYLE_GUIDE.md`：
- 使用“目标网络 / 路由方式与网关 / 分组（如适用）”卡片分区
- 网关类型使用 segmented 选择，不使用 radio 纵向堆叠
- 输入错误使用语义红色边框和错误文案提示
- 底部操作区保留取消/保存主次层级，并保持按钮尺寸与间距一致

表单 SHALL 在前缀长度下方自动显示对应的子网掩码（只读）。

#### Scenario: 添加路由弹窗遵循分区样式（macOS 14+）
- **WHEN** 用户在 macOS 14+ 打开“添加路由”Sheet
- **THEN** 弹窗按目标网络、路由方式与网关、分组三个区块展示，分组以可点击标签卡片形式呈现

#### Scenario: 添加路由弹窗遵循分区样式（macOS 12–13）
- **WHEN** 用户在 macOS 13 打开“添加路由”Sheet
- **THEN** 弹窗使用与 14+ 一致的卡片与错误样式语言，不显示分组区块，网关类型为 segmented 选择

#### Scenario: 添加使用 IP 网关的路由（macOS 14+，含分组）
- **WHEN** 用户在 macOS 14+ 上点击"添加路由"，输入网络地址 "192.168.5.0"，前缀长度 24，选择"网关 IP"，输入 "10.0.0.1"，勾选 "Office VPN" 分组，点击"保存"
- **THEN** 系统创建新路由规则（isActive 为 false），在 "All Routes" 和 "Office VPN" 视图中可见

#### Scenario: 添加使用 IP 网关的路由（macOS 12–13，无分组）
- **WHEN** 用户在 macOS 13 上点击"添加路由"，输入网络地址 "192.168.5.0"，前缀长度 24，选择"网关 IP"，输入 "10.0.0.1"，点击"保存"
- **THEN** 系统创建 RouteRuleMO 并保存到 Core Data，在路由列表中可见，不显示分组信息

#### Scenario: 添加使用网络接口的路由
- **WHEN** 用户在任意支持版本上选择"网络接口"方式，输入 "utun3"
- **THEN** 系统创建路由规则，`gatewayType` 为 `.interface`（或等效存储值），`gateway` 为 "utun3"

#### Scenario: 从分组视图中添加路由（macOS 14+ 专属）
- **WHEN** 用户在 macOS 14+ 上在 "Office VPN" 分组视图中点击"添加路由"
- **THEN** Sheet 表单中 "Office VPN" 复选框默认已勾选

### Requirement: 编辑路由规则
用户 SHALL 能够编辑已有的路由规则。编辑操作通过双击路由行或右键上下文菜单中的"编辑"选项触发，打开与添加相同的 Sheet 表单，预填充当前值。在 macOS 12–13 上，编辑操作从 Core Data `RouteRuleMO` 读取并保存数据。

#### Scenario: 编辑路由弹窗沿用添加弹窗视觉规范
- **WHEN** 用户在任意支持版本打开“编辑路由”Sheet
- **THEN** 弹窗布局、控件样式和错误反馈规则与“添加路由”一致，并预填充原有路由字段

#### Scenario: 编辑路由规则（macOS 14+）
- **WHEN** 用户在 macOS 14+ 上双击 "192.168.4.0/24" 路由行
- **THEN** 打开 Sheet 表单，预填充该路由的当前网络地址、前缀长度、网关信息和分组关联

#### Scenario: 编辑路由规则（macOS 12–13）
- **WHEN** 用户在 macOS 13 上双击路由行
- **THEN** 打开 Sheet 表单，预填充该 RouteRuleMO 的当前字段，不显示分组区域

#### Scenario: 编辑路由后保存（所有版本）
- **WHEN** 用户将网关从 "10.0.0.1" 修改为 "10.0.0.2"，点击"保存"
- **THEN** 路由规则更新，若该路由当前 isActive 为 true，系统 SHALL 先删除旧路由再添加新路由（即自动重新激活）

### Requirement: 删除路由规则
用户 SHALL 能够删除路由规则。删除操作通过右键上下文菜单"删除"、Delete 键触发。删除前 SHALL 显示确认对话框。若路由当前 isActive 为 true，系统 SHALL 先从系统路由表中删除该路由，再从持久化存储（SwiftData 或 Core Data）中删除。

#### Scenario: 删除未激活的路由（所有版本）
- **WHEN** 用户删除一条 isActive 为 false 的路由并确认
- **THEN** 路由从持久化存储中删除，列表更新

#### Scenario: 删除已激活的路由（所有版本）
- **WHEN** 用户删除一条 isActive 为 true 的路由并确认
- **THEN** 系统先通过 Helper 从系统路由表中删除该路由，再从持久化存储中删除

#### Scenario: 取消删除
- **WHEN** 用户在确认对话框中点击"取消"
- **THEN** 路由保留不变

### Requirement: 路由列表显示
路由列表 SHALL 在 macOS 14+ 上以表格形式显示路由规则，每行包含：目标网络（CIDR 格式）、路由方式、激活状态 Toggle、所属分组标签（在 All Routes 视图中显示）。

在 macOS 12–13 上路由列表 SHALL 不显示分组标签列，其余列保留。

列表顶部 SHALL 显示当前视图标题和路由统计信息。

#### Scenario: All Routes 视图显示所有路由（macOS 14+）
- **WHEN** 用户在 macOS 14+ 上选中 Sidebar 的 "All Routes"
- **THEN** 右侧列表显示所有路由规则（不重复），每条路由显示其关联的分组标签

#### Scenario: 路由列表显示（macOS 12–13）
- **WHEN** 用户在 macOS 13 上查看路由列表
- **THEN** 列表显示所有 RouteRuleMO，无分组标签列；Sidebar 不显示分组相关条目

#### Scenario: Group 视图显示过滤路由（macOS 14+ 专属）
- **WHEN** 用户在 macOS 14+ 上选中 "Office VPN" 分组
- **THEN** 右侧列表仅显示属于 "Office VPN" 的路由，不显示分组标签列

### Requirement: 输入验证
输入验证逻辑不变，在所有支持的 OS 版本上完整可用。

#### Scenario: 输入无效 IP 地址（所有版本）
- **WHEN** 用户在任意支持版本上输入网络地址 "999.0.0.1"
- **THEN** 字段显示红色边框，下方显示错误提示，保存按钮禁用

#### Scenario: 所有字段有效
- **WHEN** 用户填写的所有字段均通过验证
- **THEN** 保存按钮启用，无错误提示显示

### Requirement: 路由行上下文菜单
路由列表中的每行 SHALL 支持右键上下文菜单，包含"编辑"、"删除"、"复制路由信息"选项，在所有支持的 OS 版本上可用。在 macOS 12–13 上不显示"分配到分组"等分组相关菜单项。

#### Scenario: 复制路由信息（所有版本）
- **WHEN** 用户在任意支持版本上右键点击路由，选择"复制路由信息"
- **THEN** 系统将该路由对应的 route 命令字符串复制到系统剪贴板
