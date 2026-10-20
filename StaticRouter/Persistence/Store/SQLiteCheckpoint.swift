//
//  SQLiteCheckpoint.swift
//  StaticRouteHelper
//
//  通过独立的 SQLite 连接对 store 执行 WAL checkpoint。
//
//  背景：SQLite WAL 模式下，主文件只在「WAL 攒满 1000 页」或「最后一个连接
//  干净关闭」时才吸收 WAL 里的提交。本应用写入量小（永远达不到页数阈值）、
//  进程退出又从不关闭存储连接，曾导致全部数据永远只存在于几 KB 的 WAL
//  文件中，WAL 一旦被扰动数据即全丢。主动 checkpoint 让主文件始终保持最新，
//  把最坏丢失窗口压缩到一次刷新间隔。
//

import Foundation
import SQLite3

enum SQLiteCheckpoint {

    enum CheckpointError: Error {
        case openFailed(String)
        case checkpointFailed(code: Int32)
    }

    /// TRUNCATE 模式：checkpoint 成功后把 WAL 截断为 0 字节。
    /// 若被并发读写短暂占用（SQLITE_BUSY/LOCKED），跳过本次即可，不视为错误——
    /// 下一个刷新周期会再试。checkpoint 本身不影响持有连接的应用进程。
    static func truncateCheckpoint(storeURL: URL) throws {
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return }

        var db: OpaquePointer?
        guard sqlite3_open_v2(storeURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let db else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close_v2(db)
            throw CheckpointError.openFailed(message)
        }
        defer { sqlite3_close_v2(db) }

        var walPages: Int32 = 0
        var checkpointedPages: Int32 = 0
        let rc = sqlite3_wal_checkpoint_v2(db, nil, SQLITE_CHECKPOINT_TRUNCATE, &walPages, &checkpointedPages)
        switch rc {
        case SQLITE_OK:
            break
        case SQLITE_BUSY, SQLITE_LOCKED:
            AppLog.persistence.info("WAL checkpoint 暂时跳过（存储繁忙）：\(storeURL.lastPathComponent, privacy: .public)")
        default:
            throw CheckpointError.checkpointFailed(code: rc)
        }
    }
}
