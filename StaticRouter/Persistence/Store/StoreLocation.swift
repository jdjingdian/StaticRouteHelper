//
//  StoreLocation.swift
//  StaticRouteHelper
//
//  所有持久化存储路径的唯一事实来源（source of truth）。
//
//  历史教训：SwiftData 未指定 URL 时会落到通用共享路径
//  ~/Library/Application Support/default.store，该文件可能被其他进程
//  共用，WAL 一旦被外部扰动即丢失全部未 checkpoint 的数据。
//  因此所有存储必须收敛到按 bundle id 命名的专属目录下。
//

import Foundation

enum StoreLocation {

    /// SQLite WAL 模式下 store 的文件三件套后缀（主文件 / 预写日志 / 共享索引）
    static let fileTrioSuffixes = ["", "-wal", "-shm"]

    /// 应用专属存储目录：~/Library/Application Support/<bundle-id>/
    static var appStoreDirectory: URL {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
        let bundleID = Bundle.main.bundleIdentifier ?? "cn.magicdian.staticrouter"
        return appSupport.appendingPathComponent(bundleID, isDirectory: true)
    }

    /// SwiftData 规则库主文件：.../routerules.store
    static var swiftDataStoreURL: URL {
        appStoreDirectory.appendingPathComponent("routerules.store")
    }

    /// 旧版 SwiftData 默认落点（与其他进程共享的路径，需一次性迁走）：
    /// ~/Library/Application Support/default.store
    static var legacySharedDefaultStoreURL: URL {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
        return appSupport.appendingPathComponent("default.store")
    }

    /// 确保专属存储目录存在。
    static func ensureAppStoreDirectory() throws {
        try FileManager.default.createDirectory(
            at: appStoreDirectory,
            withIntermediateDirectories: true
        )
    }

    /// 列出 store 三件套中当前存在的文件。
    static func existingFiles(of storeURL: URL) -> [URL] {
        fileTrioSuffixes
            .map { URL(fileURLWithPath: storeURL.path + $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// 把 store 三件套（main/-wal/-shm）整体搬到新路径。
    ///
    /// 保留 -wal/-shm 是关键：SQLite 首次打开新路径时会自动 recovery，
    /// 已提交但尚未 checkpoint 进主文件的数据不会丢。
    static func moveStoreTrio(from source: URL, to destination: URL) throws {
        let fm = FileManager.default
        for suffix in fileTrioSuffixes {
            let src = URL(fileURLWithPath: source.path + suffix)
            let dst = URL(fileURLWithPath: destination.path + suffix)
            guard fm.fileExists(atPath: src.path) else { continue }
            if fm.fileExists(atPath: dst.path) {
                // 目标位置出现同名残留属于异常状态：先归档到一旁，避免新旧混写
                try quarantineFile(dst, reason: "orphan")
            }
            try fm.moveItem(at: src, to: dst)
        }
    }

    /// 把 store 三件套改名归档到一旁（保留数据、可人工回滚），绝不删除。
    static func archiveStore(at storeURL: URL, reason: String) {
        for suffix in fileTrioSuffixes {
            let file = URL(fileURLWithPath: storeURL.path + suffix)
            guard FileManager.default.fileExists(atPath: file.path) else { continue }
            let archived = URL(
                fileURLWithPath: file.path + ".archived-\(reason)-\(archiveTimestamp())"
            )
            try? FileManager.default.moveItem(at: file, to: archived)
        }
    }

    /// 把单个文件改名到一旁（保留数据、可人工回滚），绝不删除。
    static func quarantineFile(_ file: URL, reason: String) throws {
        let archived = URL(
            fileURLWithPath: file.path + ".archived-\(reason)-\(archiveTimestamp())"
        )
        try FileManager.default.moveItem(at: file, to: archived)
    }

    private static func archiveTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}
