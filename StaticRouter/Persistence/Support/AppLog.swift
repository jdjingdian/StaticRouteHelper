//
//  AppLog.swift
//  StaticRouteHelper
//
//  统一 os.Logger 入口。
//  Console.app 过滤：subsystem == "<bundle-id>"，category == persistence / migration。
//

import Foundation
import os

enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "cn.magicdian.staticrouter"

    /// 存储装载、保存、checkpoint 等持久化日常事件
    static let persistence = Logger(subsystem: subsystem, category: "persistence")

    /// 一次性存储迁移（default.store / v1.x Core Data / macOS 12–13 Core Data）
    static let migration = Logger(subsystem: subsystem, category: "migration")
}
