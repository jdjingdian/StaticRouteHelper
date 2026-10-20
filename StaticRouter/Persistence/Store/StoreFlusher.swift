//
//  StoreFlusher.swift
//  StaticRouteHelper
//
//  存储落盘调度器：定时 + 应用退出时对 backend 执行 flushToDisk（WAL checkpoint）。
//
//  历史教训：应用退出时从不关闭存储连接（无任何 teardown 代码），SQLite 的
//  close-time checkpoint 从未执行过，数据只能依赖 WAL 文件本身存活。主动定期
//  checkpoint 把最坏丢失窗口压缩到一个刷新周期（默认 60 秒）。
//

import AppKit

final class StoreFlusher {

    static let shared = StoreFlusher()

    static let defaultInterval: TimeInterval = 60

    private let flushQueue = DispatchQueue(label: "cn.magicdian.staticrouter.store-flush", qos: .utility)
    private let stateLock = NSLock()
    private var backend: PersistenceBackend?
    private var timer: DispatchSourceTimer?
    private var terminateObserver: NSObjectProtocol?

    private init() {}

    /// 启动定期刷新并注册退出刷新（幂等：重复调用只生效一次）。
    func start(backend: PersistenceBackend, interval: TimeInterval = StoreFlusher.defaultInterval) {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard timer == nil else { return }
        self.backend = backend

        let source = DispatchSource.makeTimerSource(queue: flushQueue)
        source.schedule(deadline: .now() + interval, repeating: interval)
        source.setEventHandler { [weak self] in self?.flushNow() }
        source.resume()
        timer = source

        terminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            // 退出前的最后一次机会把 WAL 数据写进主文件
            self?.flushNow()
        }
    }

    /// 立即执行一次落盘刷新（可在任意线程调用）。
    func flushNow() {
        stateLock.lock()
        let backend = self.backend
        stateLock.unlock()
        guard let backend else { return }
        do {
            try backend.flushToDisk()
        } catch {
            AppLog.persistence.error("落盘刷新失败：\(String(describing: error), privacy: .public)")
        }
    }
}
