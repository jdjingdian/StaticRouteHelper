//
//  StaticRouteHelperApp.swift
//  StaticRouteHelper
//

import SwiftUI
import CoreData
import SwiftData

@main
struct StaticRouteHelperApp: App {

    // RouterService uses ObservableObject so @StateObject works on macOS 12+
    @StateObject private var routerService = RouterService()

    // Legacy Core Data stack (macOS 12–13). Always initialized, only used on older OS.
    @StateObject private var legacyStack = LegacyPersistenceStack()

    // 编辑场景保存失败的用户可见提示
    @StateObject private var persistenceAlert = PersistenceAlertController()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(routerService)
                .environmentObject(legacyStack)
                .environmentObject(persistenceAlert)
                .environment(\.managedObjectContext, legacyStack.viewContext)
                .task { await onStartup() }
                .onReceive(NotificationCenter.default.publisher(for: .routeDidChange)) { note in
                    handleRouteChange(note)
                }
                .onReceive(NotificationCenter.default.publisher(for: .routeTableNeedsRecalibration)) { _ in
                    handleRouteTableRecalibration()
                }
        }
        .commands { MenuBarCommand() }

        Settings {
            SettingsView()
                .environmentObject(routerService)
                .environmentObject(legacyStack)
                .environment(\.managedObjectContext, legacyStack.viewContext)
        }
    }

    // MARK: - Startup

    private func onStartup() async {
        if #available(macOS 14, *) {
            await startupCalibration14()
        } else {
            await routerService.refreshSystemRoutes()
            // 12–13 路径同样需要定期 checkpoint，保证 Core Data 的 WAL 落盘
            StoreFlusher.shared.start(backend: legacyStack)
        }
        // 更新检查完全交给 Sparkle 的启动调度（startingUpdater 自带首次检查），
        // 不再手动触发——手动触发曾与 Sparkle 的自动首检叠加出两个提示窗（issue 反馈）
    }

    @available(macOS 14, *)
    private func startupCalibration14() async {
        let context = Self.sharedModelContainer.mainContext

        // 一次性迁移：v1.x Core Data → SwiftData（读失败时保留源库）
        CoreDataMigrator().migrateIfNeeded(into: context)

        // 一次性迁移：macOS 12–13 Core Data → SwiftData（出错即中止，成功才归档）
        LegacyOS13StoreMigrator(legacyStack: legacyStack).migrateIfNeeded(into: context)

        await routerService.refreshSystemRoutes()

        let descriptor = FetchDescriptor<RouteRule>()
        if let rules = try? context.fetch(descriptor) {
            RouteStateCalibrator.calibrate(rules: rules, systemRoutes: routerService.systemRoutes)
            context.saveOrLog(operation: "startupCalibration")
        } else {
            AppLog.persistence.error("启动时读取规则失败，跳过校准。")
        }

        // 启动后立即把迁移/校准产生的写入 checkpoint 进主文件，并开始定期刷新
        StoreFlusher.shared.start(backend: SwiftDataBackend.shared)
        StoreFlusher.shared.flushNow()
    }

    // MARK: - Route Change Notification Handler

    @MainActor
    private func handleRouteChange(_ notification: Notification) {
        guard #available(macOS 14, *) else { return }
        guard
            let destination = notification.userInfo?["destination"] as? String,
            let gateway = notification.userInfo?["gateway"] as? String,
            let isAdd = notification.userInfo?["isAdd"] as? Bool
        else { return }

        let context = Self.sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<RouteRule>()
        guard let rules = try? context.fetch(descriptor) else { return }

        var changed = false
        for rule in rules {
            guard rule.network == destination && rule.gateway == gateway else { continue }
            if rule.isActive != isAdd {
                rule.isActive = isAdd
                changed = true
            }
        }
        if changed { context.saveOrLog(operation: "handleRouteChange") }
    }

    /// 路由表可能失配（事件丢失 / 网络拔插）时的全量对账（issue #20）：
    /// 以当前系统路由表为准修正所有规则的 isActive 并落盘。
    @MainActor
    private func handleRouteTableRecalibration() {
        guard #available(macOS 14, *) else { return }
        let context = Self.sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<RouteRule>()
        guard let rules = try? context.fetch(descriptor) else {
            AppLog.persistence.error("对账时读取规则失败")
            return
        }
        RouteStateCalibrator.calibrate(rules: rules, systemRoutes: routerService.systemRoutes)
        context.saveOrLog(operation: "routeTableRecalibration")
    }

    // MARK: - SwiftData Container

    /// 专属路径的 SwiftData 容器（迁移、恢复与 checkpoint 逻辑见 SwiftDataBackend）
    @available(macOS 14, *)
    static let sharedModelContainer: ModelContainer = SwiftDataBackend.shared.container
}

// MARK: - AppRootView

/// Root view that injects .modelContainer on macOS 14+, passes through on macOS 12–13.
struct AppRootView: View {
    var body: some View {
        if #available(macOS 14, *) {
            MainWindow()
                .modelContainer(StaticRouteHelperApp.sharedModelContainer)
        } else {
            MainWindow()
        }
    }
}
