//
//  LegacyPersistenceStack.swift
//  StaticRouteHelper
//
//  Core Data persistence stack for macOS 12–13.
//  Wraps NSPersistentContainer and exposes the view context for SwiftUI.
//

import Foundation
import CoreData

/// Core Data persistence stack used on macOS 12–13 (legacy path).
/// On macOS 14+ the app uses SwiftData instead.
final class LegacyPersistenceStack: ObservableObject {

    static let modelName = "StaticRouteLegacy"

    // MARK: - Persistent Container

    let container: NSPersistentContainer

    /// The main thread managed object context for SwiftUI use.
    var viewContext: NSManagedObjectContext { container.viewContext }

    // MARK: - Init

    init() {
        guard let modelURL = Bundle.main.url(forResource: Self.modelName, withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("[LegacyPersistenceStack] Cannot find Core Data model '\(Self.modelName).momd' in bundle.")
        }
        container = NSPersistentContainer(name: Self.modelName, managedObjectModel: model)
        // 显式声明存储位置（与 NSPersistentContainer 的默认落点一致：
        // Application Support/<name>/<name>.sqlite），不再隐式依赖框架默认值。
        let description = NSPersistentStoreDescription(url: Self.defaultStoreURL)
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("[LegacyPersistenceStack] Failed to load persistent stores: \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    /// 与 NSPersistentContainer(name:) 默认落点一致的存储位置，显式化便于维护。
    static var defaultStoreURL: URL {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
        return appSupport
            .appendingPathComponent(modelName, isDirectory: true)
            .appendingPathComponent("\(modelName).sqlite")
    }

    // MARK: - Save

    /// Saves the view context if there are any changes.
    /// 失败记录日志（不再静默吞掉）。
    func save() {
        viewContext.saveOrLog(operation: "LegacyPersistenceStack.save")
    }

    // MARK: - PersistenceBackend

    var storeURL: URL? {
        container.persistentStoreCoordinator.persistentStores.first?.url
    }

    /// 12–13 后端在 init 中完成装载，无需额外动作。
    func prepare() throws {}

    /// 保存上下文并把 WAL checkpoint 进主文件。
    func flushToDisk() throws {
        viewContext.saveOrLog(operation: "LegacyPersistenceStack.flushToDisk")
        if let url = storeURL {
            try SQLiteCheckpoint.truncateCheckpoint(storeURL: url)
        }
    }

    // MARK: - Migration helpers

    /// Returns all RouteRuleMO records as plain dictionaries suitable for
    /// reconstructing in a SwiftData context on macOS 14+.
    ///
    /// 可能抛错（fetch 失败）。调用方必须区分「读取失败」与「确实为空」，
    /// 绝不能把错误当成空数据后删除/归档源库。
    func fetchAllRouteData() throws -> [[String: Any]] {
        let fetchRequest = NSFetchRequest<RouteRuleMO>(entityName: "RouteRuleMO")
        let results = try viewContext.fetch(fetchRequest)
        return results.map { mo in
            [
                "id": mo.id,
                "network": mo.network,
                "prefixLength": Int(mo.prefixLength),
                "gatewayType": mo.gatewayType,
                "gateway": mo.gateway,
                "isActive": mo.isActive,
                "note": mo.note as Any,
                "createdAt": mo.createdAt
            ]
        }
    }

    /// Whether the legacy Core Data store file exists on disk (used to detect upgrade scenario).
    var storeFileExists: Bool {
        guard let storeURL = container.persistentStoreCoordinator.persistentStores.first?.url else {
            return false
        }
        return FileManager.default.fileExists(atPath: storeURL.path)
    }

    /// 将 Legacy Core Data 存储三件套改名归档（保留数据、可回滚），随后从 coordinator 摘除。
    /// 绝不删除文件——历史版本的删除行为曾造成数据无法挽回。
    func archiveLegacyStoreFiles(reason: String) {
        guard let storeURL = container.persistentStoreCoordinator.persistentStores.first?.url else { return }
        // 先从 coordinator 摘除，避免后续写入到已改名路径
        if let store = container.persistentStoreCoordinator.persistentStores.first {
            try? container.persistentStoreCoordinator.remove(store)
        }
        StoreLocation.archiveStore(at: storeURL, reason: reason)
    }
}

// MARK: - PersistenceBackend

extension LegacyPersistenceStack: PersistenceBackend {}
