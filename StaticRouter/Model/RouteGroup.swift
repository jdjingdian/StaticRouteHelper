//
//  RouteGroup.swift
//  StaticRouteHelper
//

import Foundation
import SwiftData

/// 表示一个路由分组（如 "Office VPN"、"Home VPN"）
/// 与 RouteRule 构成多对多关系：一条路由可属于多个分组，一个分组可包含多条路由
@Model
final class RouteGroup {
    var id: UUID
    /// 分组名称
    var name: String
    /// 可选的 SF Symbol 图标名称（如 "network"、"lock.shield"）
    var iconName: String?
    /// 排序顺序（越小越靠前）
    var sortOrder: Int
    var createdAt: Date
    /// 该分组关联的路由规则（多对多关系的正向端）
    @Relationship(inverse: \RouteRule.groups)
    var routes: [RouteRule]

    init(
        id: UUID = UUID(),
        name: String,
        iconName: String? = nil,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        routes: [RouteRule] = []
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.routes = routes
    }
}
