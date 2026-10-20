//
//  LegacyOS13StoreMigrator.swift
//  StaticRouteHelper
//
//  macOS 12–13 的 Core Data 规则库（StaticRouteLegacy）→ SwiftData 的一次性迁移。
//  从 StaticRouteHelperApp 抽出，并修复两处数据安全隐患：
//  - fetch 出错曾被吞成空数组并照删源库 → 现在「出错即中止，源库保留」；
//  - 导入保存失败仍删除源库 → 现在只有导入成功才归档源库（改名归档，不再删除）。
//

import Foundation
import SwiftData

@available(macOS 14, *)
struct LegacyOS13StoreMigrator: StoreMigrating {

    let legacyStack: LegacyPersistenceStack

    func migrateIfNeeded(into context: ModelContext) {
        guard legacyStack.storeFileExists else { return }

        do {
            let routeData = try legacyStack.fetchAllRouteData()

            guard !routeData.isEmpty else {
                AppLog.migration.info("Legacy 存储存在但无数据，归档后跳过。")
                legacyStack.archiveLegacyStoreFiles(reason: "migrated-empty")
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

                context.insert(RouteRule(
                    network: network,
                    prefixLength: prefixLength,
                    gatewayType: gatewayType,
                    gateway: gateway,
                    isActive: isActive,
                    groups: [],
                    createdAt: createdAt
                ))
            }

            try context.save()
            legacyStack.archiveLegacyStoreFiles(reason: "migrated")
            AppLog.migration.info("Legacy 存储迁移完成，共 \(routeData.count) 条规则。")
        } catch {
            // 读取或导入失败：源库原地保留，下次启动重试。
            AppLog.migration.error("Legacy 存储迁移失败（源库已保留）：\(String(describing: error), privacy: .public)")
        }
    }
}
