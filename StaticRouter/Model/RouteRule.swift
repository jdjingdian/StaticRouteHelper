//
//  RouteRule.swift
//  StaticRouteHelper
//

import Foundation
import SwiftData

/// 表示一条用户定义的静态路由规则
@available(macOS 14, *)
@Model
final class RouteRule {
    var id: UUID
    /// 目标网络地址，如 "192.168.4.0"
    var network: String
    /// CIDR 前缀长度，如 24（对应 255.255.255.0）
    var prefixLength: Int
    /// 路由方式：IP 网关 或 网络接口
    var gatewayType: GatewayType
    /// 网关 IP 地址（ipAddress 模式）或接口名称（interface 模式）
    var gateway: String
    /// 该路由是否已在系统路由表中生效（全局状态）
    var isActive: Bool
    /// 所属路由分组（多对多）
    var groups: [RouteGroup]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        network: String,
        prefixLength: Int,
        gatewayType: GatewayType,
        gateway: String,
        isActive: Bool = false,
        groups: [RouteGroup] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.network = network
        self.prefixLength = prefixLength
        self.gatewayType = gatewayType
        self.gateway = gateway
        self.isActive = isActive
        self.groups = groups
        self.createdAt = createdAt
    }

    /// 根据 prefixLength 计算子网掩码字符串（如 24 → "255.255.255.0"）
    var subnetMask: String {
        guard prefixLength >= 0, prefixLength <= 32 else { return "0.0.0.0" }
        let mask: UInt32 = prefixLength == 0 ? 0 : (~UInt32(0) << (32 - prefixLength))
        let b1 = (mask >> 24) & 0xFF
        let b2 = (mask >> 16) & 0xFF
        let b3 = (mask >> 8) & 0xFF
        let b4 = mask & 0xFF
        return "\(b1).\(b2).\(b3).\(b4)"
    }

    /// CIDR 格式表示，如 "192.168.4.0/24"
    var cidrNotation: String {
        "\(network)/\(prefixLength)"
    }

    /// 用于向 /sbin/route 命令传递的网关类型参数（-gateway 或 -iface）
    var routeCommandGatewayFlag: String {
        gatewayType == .ipAddress ? "-gateway" : "-iface"
    }
}
