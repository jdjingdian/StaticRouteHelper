//
//  SystemRouteReader.swift
//  StaticRouteHelper
//
//  通过 PF_ROUTE raw socket + sysctl(NET_RT_DUMP) 读取内核 IPv4 路由表，
//  替换旧的 netstat 文本解析方案。无需 root 权限。
//

import Foundation
import Darwin

// MARK: - SystemRouteReader

enum SystemRouteReader {

    // MARK: - Public API

    /// 读取当前系统 IPv4 路由表快照。
    ///
    /// 使用 `sysctl(NET_RT_DUMP)` 获取内核路由表二进制数据，逐条解析 `rt_msghdr`
    /// 结构体及其后跟的 `sockaddr` 序列，映射为 `SystemRouteEntry` 数组。
    ///
    /// - Returns: 当前路由表条目数组；若系统调用失败则返回空数组并记录日志。
    static func readRoutes() -> [SystemRouteEntry] {
        // 1. 确定所需缓冲区大小
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, AF_INET, NET_RT_DUMP, 0]
        var bufferSize = 0
        guard sysctl(&mib, u_int(mib.count), nil, &bufferSize, nil, 0) == 0, bufferSize > 0 else {
            print("[SystemRouteReader] sysctl 大小查询失败：\(String(cString: strerror(errno)))")
            return []
        }

        // 2. 分配缓冲区并获取数据
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        guard sysctl(&mib, u_int(mib.count), &buffer, &bufferSize, nil, 0) == 0 else {
            print("[SystemRouteReader] sysctl 数据获取失败：\(String(cString: strerror(errno)))")
            return []
        }

        // 3. 解析 rt_msghdr 序列
        return parseRouteBuffer(buffer, size: bufferSize)
    }

    // MARK: - Private Parsing

    /// 解析 sysctl 返回的路由表缓冲区，提取所有 IPv4 条目。
    private static func parseRouteBuffer(_ buffer: [UInt8], size: Int) -> [SystemRouteEntry] {
        var results: [SystemRouteEntry] = []
        var offset = 0

        while offset < size {
            // 读取消息头
            guard offset + MemoryLayout<rt_msghdr>.size <= size else { break }

            let header: rt_msghdr = buffer.withUnsafeBytes { ptr in
                ptr.load(fromByteOffset: offset, as: rt_msghdr.self)
            }

            let msgLen = Int(header.rtm_msglen)
            guard msgLen > 0, offset + msgLen <= size else { break }

            // 仅处理 RTM_GET（路由表 dump 条目）
            if header.rtm_type == RTM_GET || header.rtm_type == RTM_ADD {
                if let entry = parseEntry(buffer: buffer, offset: offset, header: header) {
                    results.append(entry)
                }
            }

            offset += msgLen
        }

        return results
    }

    /// 从单条 rt_msghdr 消息中提取目标地址、网关、标志和接口信息。
    private static func parseEntry(buffer: [UInt8], offset: Int, header: rt_msghdr) -> SystemRouteEntry? {
        // sockaddr 序列从 rt_msghdr 结束后开始
        let addrsOffset = offset + MemoryLayout<rt_msghdr>.size
        let addrs = Int(header.rtm_addrs)

        var destination: String = ""
        var gateway: String = ""
        var networkInterface: String = ""

        var addrOffset = addrsOffset

        // 按 RTA_* 位掩码顺序遍历 sockaddr
        // 顺序：RTA_DST(0), RTA_GATEWAY(1), RTA_NETMASK(2), RTA_GENMASK(3),
        //       RTA_IFP(4), RTA_IFA(5), RTA_AUTHOR(6), RTA_BRD(7)
        for bit in 0..<8 {
            guard addrs & (1 << bit) != 0 else { continue }
            guard addrOffset + MemoryLayout<sockaddr>.size <= offset + Int(header.rtm_msglen) else { break }

            let sa: sockaddr = buffer.withUnsafeBytes { ptr in
                ptr.load(fromByteOffset: addrOffset, as: sockaddr.self)
            }

            let saLen = Int(sa.sa_len)
            let saFamily = Int(sa.sa_family)
            // sa_len == 0 时跳过（某些平台会出现空 sockaddr）
            let effectiveLen = max(saLen, MemoryLayout<sockaddr>.size)

            switch bit {
            case 0: // RTA_DST
                if saFamily == AF_INET {
                    destination = extractIPv4(buffer: buffer, offset: addrOffset)
                }
            case 1: // RTA_GATEWAY
                if saFamily == AF_INET {
                    gateway = extractIPv4(buffer: buffer, offset: addrOffset)
                } else if saFamily == AF_LINK {
                    gateway = extractInterfaceName(buffer: buffer, offset: addrOffset)
                }
            case 4: // RTA_IFP (interface)
                if saFamily == AF_LINK {
                    networkInterface = extractInterfaceName(buffer: buffer, offset: addrOffset)
                }
            default:
                break
            }

            // sockaddr 在内核消息中按 sizeof(long) 对齐
            let aligned = (effectiveLen + MemoryLayout<Int>.size - 1) & ~(MemoryLayout<Int>.size - 1)
            addrOffset += max(aligned, 1)
        }

        // 仅返回有目标地址的 IPv4 条目
        guard !destination.isEmpty else { return nil }

        // 规范化目标地址（补齐末尾省略的 ".0"）
        let normalizedDest = normalizeIPv4Destination(destination)

        // 解析标志位为可读字符串（类似 netstat 的 Flags 列）
        let flags = formatRtmFlags(header.rtm_flags)

        return SystemRouteEntry(
            destination: normalizedDest,
            gateway: gateway,
            flags: flags,
            networkInterface: networkInterface,
            expire: ""
        )
    }

    /// 从缓冲区的 sockaddr_in 中提取 IPv4 地址字符串。
    private static func extractIPv4(buffer: [UInt8], offset: Int) -> String {
        guard offset + MemoryLayout<sockaddr_in>.size <= buffer.count else { return "" }
        let sin: sockaddr_in = buffer.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: offset, as: sockaddr_in.self)
        }
        var addr = sin.sin_addr
        var result = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        guard inet_ntop(AF_INET, &addr, &result, socklen_t(INET_ADDRSTRLEN)) != nil else { return "" }
        return String(cString: result)
    }

    /// 从缓冲区的 sockaddr_dl 中提取接口名称。
    private static func extractInterfaceName(buffer: [UInt8], offset: Int) -> String {
        guard offset + MemoryLayout<sockaddr_dl>.size <= buffer.count else { return "" }
        let sdl: sockaddr_dl = buffer.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: offset, as: sockaddr_dl.self)
        }
        let nlen = Int(sdl.sdl_nlen)
        guard nlen > 0 else { return "" }
        // 接口名称紧跟在 sockaddr_dl 固定字段之后
        let nameOffset = offset + MemoryLayout<sockaddr_dl>.offset(of: \.sdl_data)!
        guard nameOffset + nlen <= buffer.count else { return "" }
        let nameBytes = buffer[nameOffset..<nameOffset + nlen]
        return String(bytes: nameBytes, encoding: .utf8) ?? ""
    }

    /// 将 rtm_flags 整数转换为类似 netstat 的标志字符串（如 "UGSc"）。
    private static func formatRtmFlags(_ flags: Int32) -> String {
        var result = ""
        // 常见标志位（与 netstat 输出对应）
        if flags & RTF_UP        != 0 { result += "U" }
        if flags & RTF_GATEWAY   != 0 { result += "G" }
        if flags & RTF_STATIC    != 0 { result += "S" }
        if flags & RTF_HOST      != 0 { result += "H" }
        if flags & RTF_REJECT    != 0 { result += "R" }
        if flags & RTF_DYNAMIC   != 0 { result += "D" }
        if flags & RTF_MODIFIED  != 0 { result += "M" }
        if flags & RTF_MULTICAST != 0 { result += "m" }
        if flags & RTF_CLONING   != 0 { result += "C" }
        if flags & RTF_PRCLONING != 0 { result += "c" }
        if flags & RTF_LLINFO    != 0 { result += "L" }
        if flags & RTF_BLACKHOLE != 0 { result += "B" }
        if flags & RTF_IFSCOPE   != 0 { result += "I" }
        return result.isEmpty ? "U" : result
    }
}
