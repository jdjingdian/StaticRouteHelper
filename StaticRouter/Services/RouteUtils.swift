//
//  RouteUtils.swift
//  StaticRouteHelper
//
//  共享路由实用函数，供 RouteStateCalibrator 和视图层复用。
//

import Foundation

/// 将 netstat / PF_ROUTE 输出的目标地址规范化为完整 IPv4 点分十进制表示。
///
/// 内核路由表中网段地址会省略末尾连续的 ".0"，例如：
/// - "192.168.3"  → "192.168.3.0"
/// - "10.0"       → "10.0.0.0"
/// - "10.0.0.0"   → "10.0.0.0"（不变）
///
/// - Parameter destination: 原始目标地址字符串
/// - Returns: 补齐到 4 段的点分十进制地址字符串
func normalizeIPv4Destination(_ destination: String) -> String {
    let parts = destination.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count < 4 else { return destination }
    let missing = 4 - parts.count
    return destination + String(repeating: ".0", count: missing)
}
