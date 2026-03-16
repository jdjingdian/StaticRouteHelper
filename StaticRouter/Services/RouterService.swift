//
//  RouterService.swift
//  StaticRouteHelper
//

import Foundation
import Observation
import SecureXPC
import Blessed
import Authorized

// MARK: - SystemRouteEntry

/// 表示系统路由表（netstat -nr）中的一条条目
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

    /// 刷新系统路由表（执行 netstat -nr -f inet 并解析输出）
    @MainActor
    func refreshSystemRoutes() async throws {
        guard helperStatus == .installed else {
            throw RouterError.helperNotAvailable
        }
        let command = RouterCommand.BuildPrintRouteCommand()
        let reply = try await sendCommandWithReply(command)
        let output = reply.standardOutput ?? ""
        systemRoutes = parseNetstatOutput(output)
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

    /// 将 netstat -nr 输出解析为 [SystemRouteEntry]
    /// 按空白字符分割，跳过表头和分隔行，健壮处理异常行
    private func parseNetstatOutput(_ output: String) -> [SystemRouteEntry] {
        var results: [SystemRouteEntry] = []
        var foundHeader = false
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // 跳过空行
            if trimmed.isEmpty { continue }
            // 跳过 "Internet:" / "Internet6:" 等节标题
            if trimmed.hasPrefix("Internet") { continue }
            // 等待 "Destination" 表头行出现
            if !foundHeader {
                if trimmed.hasPrefix("Destination") {
                    foundHeader = true
                }
                continue
            }
            // 解析数据行：至少需要 Destination Gateway Flags Refs Use Netif Expire
            let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard parts.count >= 4 else { continue }
            let destination = parts[0]
            let gateway = parts[1]
            let flags = parts[2]
            // parts[3] = Refs, parts[4] = Use (可选), parts[5] = Netif, parts[6] = Expire
            let netif = parts.count > 5 ? parts[5] : (parts.count > 3 ? parts[3] : "")
            let expire = parts.count > 6 ? parts[6] : ""

            results.append(SystemRouteEntry(
                destination: destination,
                gateway: gateway,
                flags: flags,
                networkInterface: netif,
                expire: expire
            ))
        }
        return results
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
