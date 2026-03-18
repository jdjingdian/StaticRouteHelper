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

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(routerService)
                .environmentObject(legacyStack)
                .environment(\.managedObjectContext, legacyStack.viewContext)
                .task { await onStartup() }
                .onReceive(NotificationCenter.default.publisher(for: .routeDidChange)) { note in
                    handleRouteChange(note)
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
        }
    }

    @available(macOS 14, *)
    private func startupCalibration14() async {
        let context = Self.sharedModelContainer.mainContext

        // Migrate old Core Data (CoreDataMigrator – pre-existing v1.3 → v1.4)
        CoreDataMigrator.migrateIfNeeded(into: context)

        // Migrate legacy Core Data (macOS 12–13 store) if user upgraded OS
        migrateLegacyStoreIfNeeded14(into: context)

        await routerService.refreshSystemRoutes()

        let descriptor = FetchDescriptor<RouteRule>()
        if let rules = try? context.fetch(descriptor) {
            RouteStateCalibrator.calibrate(rules: rules, systemRoutes: routerService.systemRoutes)
            try? context.save()
        }
    }

    // MARK: - Legacy → SwiftData Migration

    @available(macOS 14, *)
    private func migrateLegacyStoreIfNeeded14(into context: ModelContext) {
        guard legacyStack.storeFileExists else { return }

        let routeData = legacyStack.fetchAllRouteData()
        guard !routeData.isEmpty else {
            legacyStack.deleteLegacyStoreFiles()
            return
        }

        for data in routeData {
            guard
                let network = data["network"] as? String,
                let prefixLength = data["prefixLength"] as? Int,
                let gatewayTypeRaw = data["gatewayType"] as? String,
                let gateway = data["gateway"] as? String
            else { continue }

            let gatewayType: GatewayType = gatewayTypeRaw == "ipAddress" ? .ipAddress : .interface
            let isActive = data["isActive"] as? Bool ?? false
            let createdAt = data["createdAt"] as? Date ?? Date()

            let rule = RouteRule(
                network: network,
                prefixLength: prefixLength,
                gatewayType: gatewayType,
                gateway: gateway,
                isActive: isActive,
                groups: [],
                createdAt: createdAt
            )
            context.insert(rule)
        }

        try? context.save()
        legacyStack.deleteLegacyStoreFiles()
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
        if changed { try? context.save() }
    }

    // MARK: - SwiftData Container

    @available(macOS 14, *)
    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([RouteRule.self, RouteGroup.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("ModelContainer 初始化失败：\(error)")
        }
    }()
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
