//
//  RouteStateCalibrator.swift
//  StaticRouteHelper
//
//  应用启动时校准 SwiftData 中的 isActive 状态与实际系统路由表的一致性

import Foundation
import SwiftData

@available(macOS 14, *)
enum RouteStateCalibrator {

    /// 对比系统路由表与 SwiftData 中的 RouteRule，更新 isActive 字段使其与实际状态一致。
    /// 应在 RouterService.refreshSystemRoutes() 完成后调用。
    ///
    /// 接口型路由的特殊语义（issue #20 拔线场景）：内核在接口 link down 时
    /// 会保留 -interface 路由条目，仅凭"表里有条目"会误判为仍激活；
    /// 还需接口当前拥有 IPv4 地址（拔线即失）才算实际可用。
    @MainActor
    static func calibrate(rules: [RouteRule], systemRoutes: [SystemRouteEntry]) {
        let interfacesWithIPv4 = SystemRouteReader.interfaceNamesWithIPv4()
        for rule in rules {
            let routeExists = systemRoutes.contains { entry in
                normalizeIPv4Destination(entry.destination) == rule.network && entry.gateway == rule.gateway
            }
            let isActuallyActive: Bool
            if rule.gatewayType == .interface {
                isActuallyActive = routeExists && interfacesWithIPv4.contains(rule.gateway)
            } else {
                isActuallyActive = routeExists
            }
            if rule.isActive != isActuallyActive {
                rule.isActive = isActuallyActive
            }
        }
    }
}
