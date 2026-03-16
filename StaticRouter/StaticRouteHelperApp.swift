//
//  StaticRouteHelperApp.swift
//  StaticRouteHelper
//

import SwiftUI
import SwiftData

@main
struct StaticRouteHelperApp: App {

    // RouterService 作为全局单例，通过 Environment 注入
    @State private var routerService = RouterService()

    // ModelContainer 配置（包含 RouteRule 和 RouteGroup）
    let modelContainer: ModelContainer = {
        let schema = Schema([RouteRule.self, RouteGroup.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("ModelContainer 初始化失败：\(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainWindow()
                .environment(routerService)
                .task {
                    // 应用启动时执行 Core Data → SwiftData 数据迁移（若存在旧数据）
                    CoreDataMigrator.migrateIfNeeded(into: modelContainer.mainContext)
                    // 刷新系统路由表，然后校准 isActive 状态
                    await routerService.refreshSystemRoutes()
                    // Fetch all rules and calibrate against the fresh system route table
                    let descriptor = FetchDescriptor<RouteRule>()
                    if let rules = try? modelContainer.mainContext.fetch(descriptor) {
                        await RouteStateCalibrator.calibrate(
                            rules: rules,
                            systemRoutes: routerService.systemRoutes
                        )
                        try? modelContainer.mainContext.save()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .routeDidChange)) { notification in
                    handleRouteChangeNotification(notification)
                }
        }
        .modelContainer(modelContainer)
        .commands {
            MenuBarCommand()
        }

        Settings {
            SettingsView()
                .environment(routerService)
        }
    }

    /// 处理来自 PF_ROUTE 监听器的路由变更通知，更新匹配 RouteRule 的 isActive 状态。
    /// isActive 语义 = 当前系统实际状态，不触发自动重新激活。
    @MainActor
    private func handleRouteChangeNotification(_ notification: Notification) {
        guard
            let destination = notification.userInfo?["destination"] as? String,
            let gateway = notification.userInfo?["gateway"] as? String,
            let isAdd = notification.userInfo?["isAdd"] as? Bool
        else { return }

        let descriptor = FetchDescriptor<RouteRule>()
        guard let rules = try? modelContainer.mainContext.fetch(descriptor) else { return }

        var changed = false
        for rule in rules {
            // 仅处理 destination+gateway 均匹配的用户路由（噪音过滤）
            guard rule.network == destination && rule.gateway == gateway else { continue }
            let newActive = isAdd
            if rule.isActive != newActive {
                rule.isActive = newActive
                changed = true
            }
        }

        if changed {
            try? modelContainer.mainContext.save()
        }
    }
}

