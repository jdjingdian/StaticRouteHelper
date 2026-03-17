## 1. 项目配置与部署目标降级

- [x] 1.1 将 Xcode project 中所有 6 处 `MACOSX_DEPLOYMENT_TARGET` 从 `15.0` 改为 `12.0`（project-level Debug/Release + Static Router target Debug/Release + Helper target Debug/Release）
- [x] 1.2 将应用版本号更新为 `1.4.0`（修改 `MARKETING_VERSION` 或 Info.plist 中的 `CFBundleShortVersionString`）
- [x] 1.3 修改后执行完整构建，记录所有因降级产生的编译错误列表，作为后续任务的修复清单
- [x] 1.4 确认 Helper 工具目标的 deployment target 也正确降级至 `12.0`，并验证 Helper 代码无新编译错误

## 2. Core Data 遗留持久化栈（macOS 12–13 新路径）

- [x] 2.1 创建 `StaticRouteLegacy.xcdatamodeld` Core Data 模型文件，添加 `RouteRuleMO` 实体，字段：`id (UUID)`、`network (String)`、`prefixLength (Int16)`、`gatewayType (String)`、`gateway (String)`、`isActive (Bool, default false)`、`note (String?)`、`createdAt (Date)`
- [x] 2.2 创建 `StaticRouter/Model/RouteRuleMO.swift`，为 `RouteRuleMO` 添加 `NSManagedObject` 子类及便捷初始化方法
- [x] 2.3 创建 `StaticRouter/Services/LegacyPersistenceStack.swift`，实现 `NSPersistentContainer` 初始化、`loadPersistentStores`、对外暴露 `viewContext: NSManagedObjectContext`
- [x] 2.4 在 `LegacyPersistenceStack` 中添加从 `LegacyPersistenceStack` Core Data 迁移到 SwiftData 的 `migrateToSwiftDataIfNeeded(context: ModelContext)` 方法（读取所有 `RouteRuleMO` → 转换为 `RouteRule` → 保存 SwiftData → 删除旧存储文件）

## 3. 应用入口条件化（StaticRouteHelperApp.swift）

- [x] 3.1 将 `@State private var routerService = RouterService()` 改为根据 OS 版本条件持有：macOS 14+ 用 `@State`，macOS 12–13 用 `@StateObject`
- [x] 3.2 在 `body` 中用 `if #available(macOS 14, *)` 分支：macOS 14+ 保持现有 `.modelContainer()` + `.environment(routerService)`；macOS 12–13 使用 `.environment(\.managedObjectContext, legacyStack.viewContext)` + `.environmentObject(routerService)`
- [x] 3.3 在 macOS 14+ 启动路径中，调用 `LegacyPersistenceStack.migrateToSwiftDataIfNeeded` 检测并迁移 Legacy Core Data 数据
- [x] 3.4 在 macOS 12–13 启动路径中，初始化 `LegacyPersistenceStack` 并注入 `NSManagedObjectContext`，跳过 `RouteStateCalibrator`（SwiftData 专属，标注 `@available(macOS 14, *)`）

## 4. RouterService 条件式响应式框架适配

- [x] 4.1 在 `RouterService.swift` 顶部添加 `#if canImport(Observation)` 条件，将 `import Observation` 和 `@Observable` 标注限定在 macOS 14+ 编译路径
- [x] 4.2 在 macOS 12–13 编译路径添加 `ObservableObject` 遵循，为 `helperStatus`、`systemRoutes`、`lastError` 属性添加 `@Published`
- [x] 4.3 添加 `activateRouteMO(_ mo: RouteRuleMO) async throws` 和 `deactivateRouteMO(_ mo: RouteRuleMO) async throws` 方法，复用现有 XPC 逻辑，成功后更新 `mo.isActive` 并保存 Core Data 上下文
- [x] 4.4 将 `RouterService` 的 `@State` 持有方式（App 入口）改为 macOS 14+ 用 `@State`（`@Observable` 路径），macOS 12–13 用 `@StateObject`（`ObservableObject` 路径）

## 5. 视图层 Environment 注入修复

- [x] 5.1 将所有视图中的 `@Environment(RouterService.self) var routerService` 用 `#available(macOS 14, *)` 保护，macOS 12–13 路径改为 `@EnvironmentObject var routerService: RouterService`
- [x] 5.2 检查 `MainWindow.swift`、`RouteListView.swift`、`RouteEditSheet.swift`、`SystemRouteTableView.swift`、`GeneralSettingsView.swift`、`GeneralSettings_HelperStateView.swift` 共 6 个文件，逐一修复环境注入声明

## 6. RouteEditSheet 两参数 onChange 降级

- [x] 6.1 在 `RouteEditSheet.swift` 中找到所有 `.onChange(of: x) { old, new in }` 形式（共 4 处），用 `if #available(macOS 14, *)` 包裹两参数形式，macOS 12–13 路径改为 `.onChange(of: x) { new in }` 单参数形式
- [x] 6.2 验证联动逻辑（网关类型切换时输入字段重置等）在两条路径上行为一致

## 7. 路由列表视图 Legacy 路径（macOS 12–13）

- [x] 7.1 创建 `StaticRouter/View/LegacyRouteListView.swift`，用 `@FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \RouteRuleMO.createdAt, ascending: true)])` 驱动，显示所有 `RouteRuleMO`，列：目标网络（CIDR）、网关类型、激活状态 Toggle（不显示分组列）
- [x] 7.2 在 `MainWindow.swift` 中使用 `if #available(macOS 14, *)` 条件渲染：14+ 显示现有 `RouteListView`，12–13 显示 `LegacyRouteListView`
- [x] 7.3 在 `LegacyRouteListView` 中实现 Toggle 激活/停用逻辑（调用 `routerService.activateRouteMO` / `deactivateRouteMO`）
- [x] 7.4 在 `LegacyRouteListView` 中实现右键上下文菜单：编辑、删除（带确认）、复制路由信息

## 8. 路由编辑 Sheet Legacy 路径适配

- [x] 8.1 修改 `RouteEditSheet.swift`，使其能以 `RouteRuleMO?` 作为编辑源（macOS 12–13）和以 `RouteRule?` 作为编辑源（macOS 14+），通过 `if #available(macOS 14, *)` 分支处理保存逻辑
- [x] 8.2 在 macOS 12–13 路径中，隐藏分组多选区域（`if #available(macOS 14, *) { groupPickerSection }`）
- [x] 8.3 在 macOS 12–13 路径中，保存时将表单数据写入 `RouteRuleMO` 实体并调用 `viewContext.save()`

## 9. Sidebar 视图 Legacy 路径适配

- [x] 9.1 在 `SidebarView.swift` 中，将分组相关的 `@Query`、分组列表渲染、AddGroupButton 等用 `if #available(macOS 14, *)` 保护，macOS 12–13 只显示 "All Routes" 和 "Route Table" 条目
- [x] 9.2 修复 `SidebarView` 中的 `@Environment(RouterService.self)` 注入（同步步骤 5 的修复）

## 10. SystemRouteTableView Legacy 路径适配

- [x] 10.1 修复 `SystemRouteTableView.swift` 中的 `@Environment(RouterService.self)` 注入（macOS 12–13 改为 `@EnvironmentObject`）
- [x] 10.2 修复 `SystemRouteTableView` 中的用户路由匹配逻辑：macOS 14+ 继续与 SwiftData `@Query` 比对，macOS 12–13 改为与 `@FetchRequest` 获取的 `RouteRuleMO` 数组比对
- [x] 10.3 验证 `Date.formatted(date:time:)` API（macOS 12+），确认无需额外降级处理

## 11. 删除与校准服务 Legacy 适配

- [x] 11.1 将 `RouteStateCalibrator.swift` 的类声明标注 `@available(macOS 14, *)`，确保在 macOS 12–13 上不被调用
- [x] 11.2 在 `StaticRouteHelperApp.swift` macOS 14+ 启动路径中，`@available` 保护 `RouteStateCalibrator` 的调用

## 12. 验证与收尾

- [x] 12.1 在 macOS 12.0 deployment target 下执行完整构建，确保零编译错误
- [ ] 12.2 在 macOS 13 模拟器（若可用）或低版本真机上手动测试：添加、编辑、删除、切换路由激活状态
- [ ] 12.3 在 macOS 14+ 真机上验证：SwiftData 路径功能无回归（分组、@Query 列表、迁移逻辑）
- [ ] 12.4 测试 OS 升级场景模拟：预置 Legacy Core Data 数据，运行 macOS 14+ 路径，确认数据自动迁移且旧存储文件被删除
- [ ] 12.5 更新 Xcode Previews：SwiftData 依赖的 Preview 标注 `@available(macOS 14, *)`，Legacy 视图提供独立 Preview（注入 mock `NSManagedObjectContext`）
