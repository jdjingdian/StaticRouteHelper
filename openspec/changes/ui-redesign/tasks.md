## 1. SwiftData 数据层

- [x] 1.1 创建 `RouteRule` @Model 类，包含所有属性（id, network, prefixLength, gatewayType, gateway, isActive, groups, createdAt）、计算属性（subnetMask, cidrNotation）和 GatewayType 枚举
- [x] 1.2 创建 `RouteGroup` @Model 类，包含所有属性（id, name, iconName, sortOrder, createdAt, routes）
- [x] 1.3 配置 ModelContainer（包含 RouteRule 和 RouteGroup），在 App 入口通过 `.modelContainer()` 注入
- [x] 1.4 实现 Core Data → SwiftData 数据迁移逻辑：检测旧存储、读取 JSON blob、导入 RouteRule、删除旧存储
- [x] 1.5 创建 `RouteValidator` 工具类，提供 IPv4 地址验证、前缀长度验证、网关/接口非空验证

## 2. RouterService 服务层

- [x] 2.1 创建 `SystemRouteEntry` 结构体，用于表示系统路由表条目
- [x] 2.2 创建 `RouterError` 枚举，定义 helperNotAvailable、commandFailed、xpcError 等错误类型
- [x] 2.3 创建 `RouterService` @Observable 类，封装 XPCClient 和 HelperToolMonitor，暴露 helperStatus、systemRoutes、lastError 属性
- [x] 2.4 实现 `RouterService.activateRoute()` async throws 方法：构建 RouterCommand、XPC 调用、处理回复
- [x] 2.5 实现 `RouterService.deactivateRoute()` async throws 方法
- [x] 2.6 实现 `RouterService.refreshSystemRoutes()` async throws 方法：执行 netstat、解析输出为 [SystemRouteEntry]
- [x] 2.7 实现 netstat 输出解析逻辑：按空白字符分割、跳过表头、健壮处理异常行
- [x] 2.8 实现 `RouterService.installHelper()` 和 `uninstallHelper()` 方法
- [x] 2.9 将 RouterService 通过 SwiftUI Environment 注入到视图层级

## 3. 主界面布局（NavigationSplitView）

- [x] 3.1 重写 `StaticRouteHelperApp.swift` 入口，配置 ModelContainer 和 RouterService 注入
- [x] 3.2 创建 `MainWindow` 视图，使用 NavigationSplitView 两栏布局，绑定 sidebar selection 状态
- [x] 3.3 创建 `SidebarView` 视图，包含 "All Routes" 条目、GROUPS Section（@Query 获取 RouteGroup 列表）、SYSTEM Section
- [x] 3.4 实现 Sidebar 条目的角标（badge）显示路由数量
- [x] 3.5 实现 Sidebar 底部工具栏（"+" 添加分组按钮、齿轮设置按钮）
- [x] 3.6 实现 Helper 未安装时的横幅提示组件（显示在 Detail 区域顶部）
- [x] 3.7 配置窗口默认大小（约 800×600）和最小尺寸，设置 NavigationSplitView 列宽约束

## 4. 路由分组管理

- [x] 4.1 创建分组创建弹窗/Sheet（输入名称，验证非空）
- [x] 4.2 实现 Sidebar 中分组条目的右键上下文菜单（重命名、删除）
- [x] 4.3 实现分组重命名功能（inline editing 或弹窗）
- [x] 4.4 实现分组删除功能（确认对话框 → 解除路由关联 → 删除 RouteGroup）
- [x] 4.5 实现分组拖拽排序（更新 sortOrder 并持久化）

## 5. 路由 CRUD 操作

- [x] 5.1 创建 `RouteListView` 视图：表格形式显示路由列表（CIDR、网关/接口、Toggle、分组标签），支持 All Routes 和 Group 过滤两种模式
- [x] 5.2 创建 `RouteEditSheet` 视图：路由添加/编辑共用表单（网络地址、前缀长度、路由方式切换、网关/接口输入、分组多选）
- [x] 5.3 实现前缀长度输入及自动子网掩码显示（如 "/24 = 255.255.255.0"）
- [x] 5.4 实现表单实时输入验证（红色边框 + 错误提示 + 保存按钮禁用）
- [x] 5.5 实现从 Group 视图添加路由时自动预选当前分组
- [x] 5.6 实现路由编辑功能（双击行打开 Sheet，预填充当前值）
- [x] 5.7 实现路由删除功能（右键菜单 / Delete 键 → 确认对话框 → 若 isActive 则先停用 → 删除）
- [x] 5.8 实现路由行右键上下文菜单（编辑、删除、复制路由信息到剪贴板）
- [x] 5.9 实现路由列表顶部标题和统计信息（"N 条路由 · M 条已激活"）

## 6. 路由激活/停用

- [x] 6.1 将路由列表中的 Toggle 与 RouterService.activateRoute / deactivateRoute 绑定
- [x] 6.2 实现激活失败时 Toggle 回滚和错误提示（Alert）
- [x] 6.3 实现 Helper 未安装时 Toggle 禁用状态
- [x] 6.4 实现编辑已激活路由时自动重新激活（删除旧路由 → 添加新路由）
- [x] 6.5 实现应用启动时 isActive 状态校准（对比系统路由表与 SwiftData 中的 RouteRule）

## 7. 系统路由表视图

- [x] 7.1 创建 `SystemRouteTableView` 视图：表格显示系统路由条目（Destination、Gateway、Flags、Interface、Expire）
- [x] 7.2 实现路由条目分组显示："My Routes" section（匹配的高亮行）和 "System Routes" section
- [x] 7.3 实现用户路由匹配逻辑（比对 destination + gateway/interface 与 SwiftData 中的 RouteRule）
- [x] 7.4 实现搜索栏（按 Destination、Gateway、Interface 过滤）
- [x] 7.5 实现手动刷新按钮和底部状态栏（路由总数 + 最后刷新时间）
- [x] 7.6 实现首次进入视图时自动加载路由表

## 8. 设置和清理

- [x] 8.1 更新 `SettingsView`：移除独立的 RouterCoreConnector 实例，改用 Environment 中的 RouterService
- [x] 8.2 删除 `DEV_DEBUG/` 目录下所有旧 UI 文件（ContentView、ContentViewDev、PassEnterView、RouteEnterView、ContentScrollView、HelpView、BuyCoffeeView）
- [x] 8.3 删除 `ProcessHelper.swift`（sudo 密码方式）
- [x] 8.4 删除 `RouterCoreConnector.swift`、`AppCoreConnector.swift`（旧包装层）
- [x] 8.5 删除 `LocationProfiles.swift`、`LocationProfileSwitcher.swift`（被 RouteGroup 替代）
- [x] 8.6 删除 `CoreDataManager.swift` 和 `DataModel.xcdatamodeld`（迁移完成后）
- [x] 8.7 删除旧的 `AppModels.swift` 中的 `routeData`、`netData` 结构体（被新模型替代）
- [x] 8.8 清理 Xcode project 文件中对已删除文件的引用，确保编译通过
- [x] 8.9 更新应用最低部署目标为 macOS 15+
