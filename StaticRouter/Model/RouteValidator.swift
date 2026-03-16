//
//  RouteValidator.swift
//  StaticRouteHelper
//

import Foundation

/// 路由规则输入验证工具
struct RouteValidator {

    /// 验证 IPv4 地址格式（四段点分十进制，每段 0-255）
    static func isValidIPv4(_ address: String) -> Bool {
        let trimmed = address.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard let value = Int(part), value >= 0, value <= 255 else { return false }
            // 拒绝前导零（如 "01"）
            return part == "\(value)"
        }
    }

    /// 验证 CIDR 前缀长度（0-32）
    static func isValidPrefixLength(_ length: Int) -> Bool {
        return length >= 0 && length <= 32
    }

    /// 验证网关或接口名称（非空且去除空白后非空）
    static func isValidGatewayOrInterface(_ value: String) -> Bool {
        return !value.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// 综合验证一条路由规则的所有字段
    /// - Returns: 第一个验证失败的字段和原因，若全部通过则返回 nil
    static func validate(
        network: String,
        prefixLength: Int,
        gatewayType: GatewayType,
        gateway: String
    ) -> ValidationError? {
        guard isValidIPv4(network) else {
            return .invalidNetwork("请输入有效的 IPv4 地址（如 192.168.4.0）")
        }
        guard isValidPrefixLength(prefixLength) else {
            return .invalidPrefixLength("前缀长度必须在 0-32 之间")
        }
        if gatewayType == .ipAddress {
            guard isValidIPv4(gateway) else {
                return .invalidGateway("请输入有效的网关 IP 地址（如 10.0.0.1）")
            }
        } else {
            guard isValidGatewayOrInterface(gateway) else {
                return .invalidGateway("请输入网络接口名称（如 utun3、en0）")
            }
        }
        return nil
    }

    enum ValidationError: LocalizedError {
        case invalidNetwork(String)
        case invalidPrefixLength(String)
        case invalidGateway(String)

        var errorDescription: String? {
            switch self {
            case .invalidNetwork(let msg): return msg
            case .invalidPrefixLength(let msg): return msg
            case .invalidGateway(let msg): return msg
            }
        }

        /// 对应哪个字段验证失败
        var field: Field {
            switch self {
            case .invalidNetwork: return .network
            case .invalidPrefixLength: return .prefixLength
            case .invalidGateway: return .gateway
            }
        }

        enum Field {
            case network, prefixLength, gateway
        }
    }
}
