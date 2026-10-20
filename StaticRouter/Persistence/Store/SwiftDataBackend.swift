//
//  SwiftDataBackend.swift
//  StaticRouteHelper
//
//  macOS 14+ 的 SwiftData 持久化后端。
//
//  修复要点：
//  1. 存储落在按 bundle id 命名的专属目录，不再使用与其他进程共享的
//     default.store（GitHub issue #19/#20 规则丢失的根因）；
//  2. 首次运行时把旧共享 default.store 三件套整体改名迁移过来（保留 WAL 数据）；
//  3. 容器打开失败时把坏文件归档到一旁后重建，不再 fatalError 崩溃循环；
//  4. flushToDisk 主动执行 WAL checkpoint，主文件始终保持最新。
//

import Foundation
import SwiftData

@available(macOS 14, *)
final class SwiftDataBackend: PersistenceBackend {

    static let shared: SwiftDataBackend = {
        let backend = SwiftDataBackend(schema: Schema([RouteRule.self, RouteGroup.self]))
        do {
            try backend.prepare()
        } catch {
            // prepare 内部已对「容器打不开」做了归档重建，能抛到这里的只剩
            // 目录不可写等环境级问题，此时无法以任何形态持久化，只能终止。
            AppLog.persistence.fault("SwiftDataBackend 装载失败：\(String(describing: error), privacy: .public)")
            fatalError("SwiftDataBackend prepare failed: \(error)")
        }
        return backend
    }()

    private let schema: Schema
    private(set) var container: ModelContainer!

    private init(schema: Schema) {
        self.schema = schema
    }

    var storeURL: URL? { StoreLocation.swiftDataStoreURL }

    func prepare() throws {
        try StoreLocation.ensureAppStoreDirectory()
        DefaultStoreMigrator().migrateIfNeeded()
        container = try makeContainerRecovering()
    }

    func flushToDisk() throws {
        guard let storeURL else { return }
        try SQLiteCheckpoint.truncateCheckpoint(storeURL: storeURL)
    }

    /// 打开容器；失败则把坏文件归档到一旁（保留供检查）后重建空库。
    private func makeContainerRecovering() throws -> ModelContainer {
        let url = StoreLocation.swiftDataStoreURL
        do {
            let config = ModelConfiguration(schema: schema, url: url)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            AppLog.persistence.error(
                "ModelContainer 打开失败（已归档坏文件并重建）：\(String(describing: error), privacy: .public)"
            )
            StoreLocation.archiveStore(at: url, reason: "unopenable")
            let fresh = ModelConfiguration(schema: schema, url: url)
            return try ModelContainer(for: schema, configurations: [fresh])
        }
    }
}
