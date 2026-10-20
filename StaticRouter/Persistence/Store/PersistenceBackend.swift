//
//  PersistenceBackend.swift
//  StaticRouteHelper
//
//  持久化后端抽象：把「存储位置、生命周期、落盘策略」与具体框架解耦。
//
//  现有两个实现：
//  - SwiftDataBackend（macOS 14+，SwiftData）
//  - LegacyPersistenceStack（macOS 12–13，Core Data）
//  未来若更换存储方案，新增一个 conformer 即可，调用方（App、StoreFlusher）不变。
//

import Foundation

protocol PersistenceBackend: AnyObject {

    /// 主存储文件位置（WAL 模式下与 -wal/-shm 配套的主文件）。
    /// 后端尚未装载时可能为 nil。
    var storeURL: URL? { get }

    /// 激活后端：确保目录存在、执行一次性迁移、装载容器。
    /// 装载失败时应优先保全数据（归档而非删除），并尝试重建空库。
    func prepare() throws

    /// 把尚未落盘的数据刷到磁盘（保存上下文 + WAL checkpoint）。
    /// 可能在后台线程调用，实现需自行保证线程安全。
    func flushToDisk() throws
}
