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
                    if routerService.helperStatus == .installed {
                        try? await routerService.refreshSystemRoutes()
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
}
