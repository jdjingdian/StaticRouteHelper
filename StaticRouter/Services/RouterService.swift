//
//  RouterService.swift
//  StaticRouteHelper
//

import Foundation
import Observation
import SecureXPC
import Blessed
import Authorized
import SwiftData
import Darwin

// MARK: - Notification Names

extension Notification.Name {
    /// 当 PF_ROUTE 监听到路由变化（RTM_ADD / RTM_DELETE）时发布。
    /// userInfo keys: "destination" (String), "gateway" (String), "isAdd" (Bool)
    static let routeDidChange = Notification.Name("cn.magicdian.staticrouter.routeDidChange")
}

// MARK: - SystemRouteEntry

/// 表示系统路由表中的一条条目（来自 PF_ROUTE socket）
struct SystemRouteEntry: Identifiable {
    let id = UUID()
    let destination: String
    let gateway: String
    let flags: String
    let networkInterface: String
    let expire: String
}

// MARK: - RouterError

/// RouterService 操作错误类型
enum RouterError: LocalizedError {
    /// Helper 未安装或不可达
    case helperNotAvailable
    /// route/netstat 命令执行失败
    case commandFailed(exitCode: Int32, stderr: String)
    /// XPC 通信错误
    case xpcError(String)

    var errorDescription: String? {
        switch self {
        case .helperNotAvailable:
            return "Helper 工具未安装或不可用，请前往设置安装。"
        case .commandFailed(let code, let stderr):
            let detail = stderr.isEmpty ? "退出码：\(code)" : stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return "命令执行失败：\(detail)"
        case .xpcError(let msg):
            return "XPC 通信错误：\(msg)"
        }
    }
}

// MARK: - RouterService

/// 统一路由操作服务，封装 XPC 通信和 Helper 状态监控
@Observable
final class RouterService {

    // MARK: Public State

    /// Helper 安装状态
    private(set) var helperStatus: HelperToolInstallationState = .notInstalled
    /// 系统路由表缓存（来自 netstat -nr -f inet）
    private(set) var systemRoutes: [SystemRouteEntry] = []
    /// 最近一次操作错误
    var lastError: RouterError?

    // MARK: Private

    private var xpcClient: XPCClient
    private let helperMonitor: HelperToolMonitor
    private let sharedConstants: SharedConstant

    /// 后台 PF_ROUTE 监听任务
    private var monitoringTask: Task<Void, Never>?

    // MARK: Init

    init() {
        do {
            sharedConstants = try SharedConstant()
        } catch {
            fatalError("SharedConstant 初始化失败，请检查 PropertyListModifier.swift 脚本：\(error)")
        }
        xpcClient = XPCClient.forMachService(named: sharedConstants.machServiceName)
        helperMonitor = HelperToolMonitor(constants: sharedConstants)

        // 初始化时检查 Helper 状态
        let status = helperMonitor.determineStatus()
        helperStatus = Self.resolveInstallationState(status, constants: sharedConstants)

        // 监听 Helper 安装目录变化，实时更新状态
        helperMonitor.start { [weak self] newStatus in
            guard let self else { return }
            let state = Self.resolveInstallationState(newStatus, constants: self.sharedConstants)
            DispatchQueue.main.async {
                self.helperStatus = state
            }
        }

        // 启动 PF_ROUTE 实时监听
        startRouteMonitor()
    }

    deinit {
        monitoringTask?.cancel()
    }

    // MARK: - Route Operations

    /// 激活路由（向系统路由表添加一条静态路由）
    func activateRoute(_ rule: RouteRule) async throws {
        guard helperStatus == .installed else {
            throw RouterError.helperNotAvailable
        }
        let command = RouterCommand.BuildManageRouteCommand(
            addToRoute: true,
            network: rule.network,
            mask: rule.subnetMask,
            gateway: rule.gateway,
            gatewayType: rule.gatewayType == .ipAddress ? .ipaddr : .interface
        )
        try await sendCommand(command)
    }

    /// 停用路由（从系统路由表删除一条静态路由）
    func deactivateRoute(_ rule: RouteRule) async throws {
        guard helperStatus == .installed else {
            throw RouterError.helperNotAvailable
        }
        let command = RouterCommand.BuildManageRouteCommand(
            addToRoute: false,
            network: rule.network,
            mask: rule.subnetMask,
            gateway: rule.gateway,
            gatewayType: rule.gatewayType == .ipAddress ? .ipaddr : .interface
        )
        try await sendCommand(command)
    }

    // MARK: - System Routes

    /// 刷新系统路由表（通过 PF_ROUTE socket 读取内核路由表）
    @MainActor
    func refreshSystemRoutes() async {
        systemRoutes = SystemRouteReader.readRoutes()
    }

    // MARK: - Helper Management

    /// 安装 Helper 工具（弹出授权对话框）
    func installHelper() throws {
        do {
            try PrivilegedHelperManager.shared.authorizeAndBless(
                message: "安装 Helper 以管理系统路由",
                icon: nil
            )
        } catch AuthorizationError.canceled {
            // 用户取消，无需反馈
        } catch {
            throw RouterError.xpcError(error.localizedDescription)
        }
    }

    /// 卸载 Helper 工具
    func uninstallHelper() async throws {
        guard helperStatus == .installed else { return }
        do {
            try await xpcClient.send(to: SharedConstant.uninstallRoute)
        } catch {
            throw RouterError.xpcError(error.localizedDescription)
        }
    }

    // MARK: - Private Helpers

    /// 发送命令并等待回复，解析错误
    private func sendCommandWithReply(_ command: RouterCommand) async throws -> RouterCommandReply {
        do {
            return try await withCheckedThrowingContinuation { continuation in
                xpcClient.sendMessage(command, to: SharedConstant.commandRoute) { result in
                    switch result {
                    case .success(let reply):
                        continuation.resume(returning: reply)
                    case .failure(let error):
                        continuation.resume(throwing: RouterError.xpcError(error.localizedDescription))
                    }
                }
            }
        } catch let routerErr as RouterError {
            throw routerErr
        } catch {
            throw RouterError.xpcError(error.localizedDescription)
        }
    }

    /// 发送命令（仅检查回复的退出码，不返回输出）
    private func sendCommand(_ command: RouterCommand) async throws {
        let reply = try await sendCommandWithReply(command)
        if reply.terminationStatus != 0 {
            throw RouterError.commandFailed(
                exitCode: reply.terminationStatus,
                stderr: reply.standardError ?? ""
            )
        }
    }

    // MARK: - PF_ROUTE Monitor

    /// 启动后台 PF_ROUTE socket 监听循环，订阅 RTM_ADD / RTM_DELETE 事件，
    /// 自动同步受影响 RouteRule 的 isActive 状态到内存（不触发 XPC 重新激活）。
    private func startRouteMonitor() {
        monitoringTask = Task.detached(priority: .background) { [weak self] in
            // 打开 PF_ROUTE raw socket（不需要 root 权限）
            let sock = socket(PF_ROUTE, SOCK_RAW, AF_UNSPEC)
            guard sock >= 0 else {
                print("[RouteMonitor] 无法打开 PF_ROUTE socket：\(String(cString: strerror(errno)))")
                return
            }
            defer { close(sock) }

            var buf = [UInt8](repeating: 0, count: 4096)

            while !Task.isCancelled {
                let n = read(sock, &buf, buf.count)
                guard n > 0, !Task.isCancelled else { break }

                guard n >= MemoryLayout<rt_msghdr>.size else { continue }

                let header: rt_msghdr = buf.withUnsafeBytes { ptr in
                    ptr.load(fromByteOffset: 0, as: rt_msghdr.self)
                }

                // 仅处理 RTM_ADD 和 RTM_DELETE
                guard header.rtm_type == RTM_ADD || header.rtm_type == RTM_DELETE else { continue }

                // 过滤非 IPv4 消息（通过解析第一个 sockaddr 的地址族）
                guard let (destination, gateway) = Self.extractAddrsFromMessage(buf, size: n, header: header) else {
                    continue
                }

                let isAdd = header.rtm_type == RTM_ADD

                if let self = self {
                    await self.handleRouteEvent(
                        destination: destination,
                        gateway: gateway,
                        isAdd: isAdd
                    )
                }
            }
        }
    }

    /// 在 MainActor 上处理路由变更事件：
    /// - 若 destination+gateway 匹配某条 RouteRule，更新其 isActive
    /// - 否则仅刷新 systemRoutes 快照（不触发 SwiftData 写入）
    @MainActor
    private func handleRouteEvent(destination: String, gateway: String, isAdd: Bool) {
        // 先刷新快照（非阻塞，读内存）
        systemRoutes = SystemRouteReader.readRoutes()

        // 查找匹配的 RouteRule（使用规范化目标地址）
        // systemRoutes 已经包含规范化的目标地址（SystemRouteReader 内部已调用 normalizeIPv4Destination）
        // 此处直接使用传入的 destination（来自内核消息，已规范化）与 rule.network 比较
        let normalizedDest = normalizeIPv4Destination(destination)

        // 通过 @Observable 机制触发 UI 更新；SwiftData 写入通过已有的 RouteRule @Model 引用完成
        // 注意：此处无法直接访问 ModelContext，需通过已有的 RouteRule 引用修改（引用由调用方持有）
        // 使用全局通知将路由事件传递给持有 ModelContext 的视图层
        NotificationCenter.default.post(
            name: .routeDidChange,
            object: nil,
            userInfo: [
                "destination": normalizedDest,
                "gateway": gateway,
                "isAdd": isAdd
            ]
        )
    }

    /// 从 PF_ROUTE 消息缓冲区中提取目标地址和网关（仅 IPv4）。
    /// 返回 nil 表示消息不含 IPv4 目标地址（即非 IPv4 路由事件，应被跳过）。
    private static func extractAddrsFromMessage(_ buf: [UInt8], size: Int, header: rt_msghdr) -> (destination: String, gateway: String)? {
        let addrsStart = MemoryLayout<rt_msghdr>.size
        guard addrsStart < size else { return nil }

        var offset = addrsStart
        let addrs = Int(header.rtm_addrs)
        var destination: String?
        var gateway: String = ""

        for bit in 0..<8 {
            guard addrs & (1 << bit) != 0 else { continue }
            guard offset + MemoryLayout<sockaddr>.size <= size else { break }

            let sa: sockaddr = buf.withUnsafeBytes { ptr in
                ptr.load(fromByteOffset: offset, as: sockaddr.self)
            }
            let saLen = Int(sa.sa_len)
            let saFamily = Int(sa.sa_family)
            let effectiveLen = max(saLen, MemoryLayout<sockaddr>.size)

            switch bit {
            case 0: // RTA_DST
                guard saFamily == AF_INET else { return nil } // 非 IPv4，跳过整条消息
                if offset + MemoryLayout<sockaddr_in>.size <= size {
                    let sin: sockaddr_in = buf.withUnsafeBytes { $0.load(fromByteOffset: offset, as: sockaddr_in.self) }
                    var addr = sin.sin_addr
                    var result = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                    if inet_ntop(AF_INET, &addr, &result, socklen_t(INET_ADDRSTRLEN)) != nil {
                        destination = String(cString: result)
                    }
                }
            case 1: // RTA_GATEWAY
                if saFamily == AF_INET, offset + MemoryLayout<sockaddr_in>.size <= size {
                    let sin: sockaddr_in = buf.withUnsafeBytes { $0.load(fromByteOffset: offset, as: sockaddr_in.self) }
                    var addr = sin.sin_addr
                    var result = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                    if inet_ntop(AF_INET, &addr, &result, socklen_t(INET_ADDRSTRLEN)) != nil {
                        gateway = String(cString: result)
                    }
                }
            default:
                break
            }

            let aligned = (effectiveLen + MemoryLayout<Int>.size - 1) & ~(MemoryLayout<Int>.size - 1)
            offset += max(aligned, 1)
        }

        guard let dest = destination else { return nil }
        return (dest, gateway)
    }

    // MARK: - Status Resolution

    private static func resolveInstallationState(
        _ status: HelperToolMonitor.InstallationStatus,
        constants: SharedConstant
    ) -> HelperToolInstallationState {
        guard status.registeredWithLaunchd else { return .notInstalled }
        guard status.registrationPropertyListExists else { return .notInstalled }
        guard case .exists(let version) = status.helperToolExecutable else { return .notInstalled }
        if version < constants.helperToolVersion {
            return .needUpgrade
        } else if version == constants.helperToolVersion {
            return .installed
        } else {
            return .notCompatible
        }
    }
}
