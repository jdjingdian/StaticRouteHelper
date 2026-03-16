//
//  RouteStateCalibrator.swift
//  StaticRouteHelper
//
//  应用启动时校准 SwiftData 中的 isActive 状态与实际系统路由表的一致性

import Foundation
import SwiftData

enum RouteStateCalibrator {

    /// 对比系统路由表与 SwiftData 中的 RouteRule，更新 isActive 字段使其与实际状态一致。
    /// 应在 RouterService.refreshSystemRoutes() 完成后调用。
    @MainActor
    static func calibrate(rules: [RouteRule], systemRoutes: [SystemRouteEntry]) {
        for rule in rules {
            let isActuallyActive = systemRoutes.contains { entry in
                normalizeIPv4Destination(entry.destination) == rule.network && entry.gateway == rule.gateway
            }
            if rule.isActive != isActuallyActive {
                rule.isActive = isActuallyActive
            }
        }
    }
}
