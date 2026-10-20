//
//  CoreDataMigrator.swift
//  StaticRouteHelper
//
//  迁移逻辑：检测 v1.x Core Data 存储（JSON blob），将数据导入 SwiftData。
//
//  历史教训：旧实现里「读不到旧模型 / 加载失败」都被当成空数据处理，
//  而读完之后源库会被无条件删除——v1.x 升级用户必然丢失全部规则。
//  现在遵守 StoreMigrating 的数据安全红线：
//  - 读取失败 ≠ 数据为空：读不出内容时中止迁移并保留源库；
//  - 源库只改名归档，绝不删除。
//

import Foundation
import CoreData
import SwiftData

/// 旧版 routeData 结构体（用于解码 Core Data JSON blob）
struct LegacyRouteData: Codable {
    var network: String
    var mask: String
    var gateway: String
    var interface: String
    var isOn: Bool
}

/// Core Data → SwiftData 数据迁移工具
@available(macOS 14, *)
struct CoreDataMigrator: StoreMigrating {

    /// 读取结果：loaded 与 unreadable 严格区分，后者必须保留源库
    enum LegacyReadOutcome {
        case loaded([LegacyRouteData])
        case unreadable(String)
    }

    func migrateIfNeeded(into context: ModelContext) {
        guard let storeURL = Self.legacyStoreURL() else { return }
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return }

        AppLog.migration.info("检测到 v1.x Core Data 存储，开始迁移...")

        switch Self.readLegacyRoutes(storeURL: storeURL) {
        case .loaded(let legacyRoutes) where !legacyRoutes.isEmpty:
            do {
                try Self.importRoutes(legacyRoutes, into: context)
                StoreLocation.archiveStore(at: storeURL, reason: "migrated")
                AppLog.migration.info("已导入 \(legacyRoutes.count) 条路由，旧存储已归档。")
            } catch {
                // 导入失败：源库原地保留，下次启动重试。
                AppLog.migration.error("v1.x 存储导入失败（源库已保留）：\(String(describing: error), privacy: .public)")
            }

        case .loaded:
            // 能读但确实为空：归档旧库，避免每次启动重复检测。
            StoreLocation.archiveStore(at: storeURL, reason: "migrated-empty")
            AppLog.migration.info("v1.x 存储为空，已归档。")

        case .unreadable(let reason):
            // 读不出内容（模型缺失 / 存储损坏）：保留源库，绝不删除。
            AppLog.migration.error("v1.x 存储不可读，跳过迁移并保留源库：\(reason, privacy: .public)")
        }
    }

    // MARK: - Private

    /// 旧 Core Data 存储文件 URL（默认位置：Application Support/DataModel.sqlite）
    private static func legacyStoreURL() -> URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        // NSPersistentContainer 默认将数据库放在 Application Support/<BundleID>/DataModel.sqlite
        // 但实际路径取决于应用 bundle ID；先尝试带 bundle ID 的路径，再尝试直接路径
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        let withID = appSupport.appendingPathComponent(bundleID).appendingPathComponent("DataModel.sqlite")
        if FileManager.default.fileExists(atPath: withID.path) { return withID }
        let direct = appSupport.appendingPathComponent("DataModel.sqlite")
        if FileManager.default.fileExists(atPath: direct.path) { return direct }
        return nil
    }

    /// 读取旧 Core Data 中的路由数据（JSON blob）。
    /// 任何失败都以 unreadable 返回，绝不与「确实为空」混淆。
    private static func readLegacyRoutes(storeURL: URL) -> LegacyReadOutcome {
        // 临时构建一个不持久化到现有路径的 NSPersistentContainer 读取旧数据
        guard let modelURL = Bundle.main.url(forResource: "DataModel", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            return .unreadable("bundle 中找不到 DataModel.momd（v1.x 模型已随新版移除），无法解读旧库")
        }

        let container = NSPersistentContainer(name: "DataModel", managedObjectModel: model)
        let description = NSPersistentStoreDescription(url: storeURL)
        description.isReadOnly = true
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        let semaphore = DispatchSemaphore(value: 0)
        container.loadPersistentStores { _, error in
            loadError = error
            semaphore.signal()
        }
        semaphore.wait()

        if let loadError {
            return .unreadable("加载旧存储失败：\(loadError)")
        }

        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "RouteData")
        do {
            let objects = try container.viewContext.fetch(fetchRequest)
            let decoder = JSONDecoder()
            var routes: [LegacyRouteData] = []
            for obj in objects {
                if let data = obj.value(forKey: "values") as? Data {
                    if let list = try? decoder.decode([LegacyRouteData].self, from: data) {
                        routes.append(contentsOf: list)
                    }
                }
            }
            return .loaded(routes)
        } catch {
            return .unreadable("读取旧数据失败：\(error)")
        }
    }

    /// 将旧路由数据导入 SwiftData（isActive = false，groups = 空）
    private static func importRoutes(_ routes: [LegacyRouteData], into context: ModelContext) throws {
        for legacy in routes {
            // 将子网掩码转换为前缀长度
            let prefixLength = prefixLengthFromMask(legacy.mask)
            // 判断是 IP 网关还是接口路由（旧版本用 interface 字段区分）
            let gatewayType: GatewayType
            let gateway: String
            if !legacy.interface.trimmingCharacters(in: .whitespaces).isEmpty {
                gatewayType = .interface
                gateway = legacy.interface
            } else {
                gatewayType = .ipAddress
                gateway = legacy.gateway
            }

            let rule = RouteRule(
                network: legacy.network,
                prefixLength: prefixLength,
                gatewayType: gatewayType,
                gateway: gateway,
                isActive: false
            )
            context.insert(rule)
        }
        try context.save()
    }

    /// 将子网掩码字符串（如 "255.255.255.0"）转换为前缀长度（如 24）
    private static func prefixLengthFromMask(_ mask: String) -> Int {
        let parts = mask.split(separator: ".").compactMap { UInt32($0) }
        guard parts.count == 4 else { return 24 } // 默认值
        let combined: UInt32 = (parts[0] << 24) | (parts[1] << 16) | (parts[2] << 8) | parts[3]
        return combined.nonzeroBitCount
    }
}
