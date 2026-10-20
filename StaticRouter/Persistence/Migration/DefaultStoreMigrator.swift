//
//  DefaultStoreMigrator.swift
//  StaticRouteHelper
//
//  修复历史问题的一次性迁移：把 SwiftData 默认落点的共享存储
//  ~/Library/Application Support/default.store（可能与其他进程共用，且 WAL
//  从未被 checkpoint 过）整体搬到本应用专属目录。
//
//  采用文件级改名而非逐条拷贝：保留 -wal/-shm，SQLite 首次打开新路径时
//  自动 recovery，任何已提交但尚未 checkpoint 的数据都不会丢。
//

import Foundation

/// 在 ModelContainer 创建之前调用（它决定容器要打开的文件），
/// 与 StoreMigrating（容器创建后向 context 导入）属于不同阶段。
struct DefaultStoreMigrator {

    func migrateIfNeeded() {
        let fm = FileManager.default
        let source = StoreLocation.legacySharedDefaultStoreURL
        let destination = StoreLocation.swiftDataStoreURL

        guard fm.fileExists(atPath: source.path) else { return }
        guard !fm.fileExists(atPath: destination.path) else { return }

        do {
            try StoreLocation.moveStoreTrio(from: source, to: destination)
            AppLog.migration.info("已将共享 default.store 迁移至专属路径：\(destination.path, privacy: .public)")
        } catch {
            // 迁移失败：源文件原地保留，应用仍以专属路径新建空库继续工作，
            // 旧数据可由用户人工恢复。
            AppLog.migration.error("default.store 迁移失败（源文件已保留）：\(String(describing: error), privacy: .public)")
        }
    }
}
