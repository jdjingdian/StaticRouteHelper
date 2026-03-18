//
//  RouterService.swift
//  StaticRouteHelper
//

import Foundation
import Combine
import SecureXPC
import Blessed
import Authorized
import CoreData
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
    /// PF_ROUTE socket 写入失败
    case routeWriteFailed(String)
    /// XPC 通信错误
    case xpcError(String)
    /// 自动重装流程正在进行
    case helperRecoveryInProgress
    /// 自动重装流程失败
    case helperRecoveryFailed(String)

    var errorDescription: String? {
        switch self {
        case .helperNotAvailable:
            return "Helper 工具未安装或不可用，请前往设置安装。"
        case .routeWriteFailed(let message):
            return "路由操作失败：\(message)"
        case .xpcError(let msg):
            return "XPC 通信错误：\(msg)"
        case .helperRecoveryInProgress:
            return "自动重装进行中，请稍候。"
        case .helperRecoveryFailed(let msg):
            return "自动重装失败：\(msg)"
        }
    }
}

struct SMAppServiceRecoveryState: Identifiable {
    let id = UUID()
    let errorMessage: String
    let canAutoReinstall: Bool
}

// MARK: - RouterService

/// 统一路由操作服务，封装 XPC 通信和 Helper 状态监控
/// Uses ObservableObject so it works as @EnvironmentObject on macOS 12+.
final class RouterService: ObservableObject {

    // MARK: Public State

    /// Helper 安装状态
    @Published private(set) var helperStatus: HelperToolInstallationState = .notInstalled
    /// 系统路由表缓存（来自 netstat -nr -f inet）
    @Published private(set) var systemRoutes: [SystemRouteEntry] = []
    /// 最近一次操作错误
    @Published var lastError: RouterError?
    /// SMAppService 发生 XPC 通信失败时的可恢复提示状态
    @Published var smAppServiceRecoveryState: SMAppServiceRecoveryState?
    /// 自动重装是否正在进行（用于并发保护和 UI 禁用）
    @Published private(set) var isAutoReinstallInProgress: Bool = false

    // MARK: Internal

    /// The privilege manager — exposed for UI access to activeMethod, isOptimizedMode, etc.
    let helperManager: PrivilegedHelperManager

    // MARK: Private

    private let jobBlessXPCClient: XPCClient
    private let appServiceXPCClient: XPCClient
    private let helperMonitor: HelperToolMonitor
    private let sharedConstants: SharedConstant

    /// 后台 PF_ROUTE 监听任务
    private var monitoringTask: Task<Void, Never>?

    /// Combine subscriptions for helperManager state propagation.
    private var helperManagerCancellables = Set<AnyCancellable>()

    // MARK: Init

    init() {
        do {
            sharedConstants = try SharedConstant()
        } catch {
            fatalError("SharedConstant 初始化失败，请检查 PropertyListModifier.swift 脚本：\(error)")
        }
        jobBlessXPCClient = XPCClient.forMachService(named: sharedConstants.jobBlessMachServiceName)
        appServiceXPCClient = XPCClient.forMachService(named: sharedConstants.appServiceMachServiceName)
        helperMonitor = HelperToolMonitor(constants: sharedConstants)
        helperManager = PrivilegedHelperManager(constants: sharedConstants)

        // Derive initial helperStatus from manager state
        helperStatus = Self.resolveInstallationState(
            activeMethod: helperManager.activeMethod,
            isPendingApproval: helperManager.isPendingApproval,
            constants: sharedConstants
        )

        // Watch helper directories; on change, refresh manager state and re-derive helperStatus
        helperMonitor.start { [weak self] _ in
            guard let self else { return }
            self.helperManager.refreshState()
            let state = Self.resolveInstallationState(
                activeMethod: self.helperManager.activeMethod,
                isPendingApproval: self.helperManager.isPendingApproval,
                constants: self.sharedConstants
            )
            DispatchQueue.main.async {
                self.helperStatus = state
            }
        }

        // Propagate helperManager state changes (from didBecomeActive / Timer monitoring)
        // to helperStatus so the UI reflects switch state changes in real time.
        helperManager.$activeMethod
            .combineLatest(helperManager.$isPendingApproval)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (activeMethod, isPendingApproval) in
                guard let self else { return }
                self.helperStatus = Self.resolveInstallationState(
                    activeMethod: activeMethod,
                    isPendingApproval: isPendingApproval,
                    constants: self.sharedConstants
                )
            }
            .store(in: &helperManagerCancellables)

        // 启动 PF_ROUTE 实时监听
        startRouteMonitor()
    }

    deinit {
        monitoringTask?.cancel()
    }

    // MARK: - Route Operations (SwiftData path – macOS 14+)

    /// 激活路由（向系统路由表添加一条静态路由）
    @available(macOS 14, *)
    func activateRoute(_ rule: RouteRule) async throws {
        guard helperStatus == .installed else {
            throw RouterError.helperNotAvailable
        }
        let request = RouteWriteRequest(
            network: rule.network,
            mask: rule.subnetMask,
            gateway: rule.gateway,
            gatewayType: rule.gatewayType == .ipAddress ? .ipAddress : .interface,
            add: true
        )
        try await sendCommand(request)
    }

    /// 停用路由（从系统路由表删除一条静态路由）
    @available(macOS 14, *)
    func deactivateRoute(_ rule: RouteRule) async throws {
        guard helperStatus == .installed else {
            throw RouterError.helperNotAvailable
        }
        let request = RouteWriteRequest(
            network: rule.network,
            mask: rule.subnetMask,
            gateway: rule.gateway,
            gatewayType: rule.gatewayType == .ipAddress ? .ipAddress : .interface,
            add: false
        )
        try await sendCommand(request)
    }

    // MARK: - Route Operations (Core Data path – macOS 12–13)

    /// 激活路由（向系统路由表添加一条静态路由）—— Core Data 路径
    func activateRouteMO(_ mo: RouteRuleMO, context: NSManagedObjectContext) async throws {
        guard helperStatus == .installed else {
            throw RouterError.helperNotAvailable
        }
        let request = RouteWriteRequest(
            network: mo.network,
            mask: mo.subnetMask,
            gateway: mo.gateway,
            gatewayType: mo.gatewayType == "ipAddress" ? .ipAddress : .interface,
            add: true
        )
        try await sendCommand(request)
        await MainActor.run {
            mo.isActive = true
            try? context.save()
        }
    }

    /// 停用路由（从系统路由表删除一条静态路由）—— Core Data 路径
    func deactivateRouteMO(_ mo: RouteRuleMO, context: NSManagedObjectContext) async throws {
        guard helperStatus == .installed else {
            throw RouterError.helperNotAvailable
        }
        let request = RouteWriteRequest(
            network: mo.network,
            mask: mo.subnetMask,
            gateway: mo.gateway,
            gatewayType: mo.gatewayType == "ipAddress" ? .ipAddress : .interface,
            add: false
        )
        try await sendCommand(request)
        await MainActor.run {
            mo.isActive = false
            try? context.save()
        }
    }

    // MARK: - System Routes

    /// 刷新系统路由表（通过 PF_ROUTE socket 读取内核路由表）
    @MainActor
    func refreshSystemRoutes() async {
        systemRoutes = SystemRouteReader.readRoutes()
    }

    // MARK: - Helper Management

    /// 安装 Helper 工具 — delegates entirely to PrivilegedHelperManager.
    /// The caller specifies which install method the user selected.
    @MainActor
    func installHelper(method: InstallMethod) async throws -> InstallResult {
        let result = try await helperManager.install(method: method)
        // Refresh published helperStatus after install attempt
        helperStatus = Self.resolveInstallationState(
            activeMethod: helperManager.activeMethod,
            isPendingApproval: helperManager.isPendingApproval,
            constants: sharedConstants
        )
        return result
    }

    /// 卸载 Helper 工具 — delegates entirely to PrivilegedHelperManager.
    @MainActor
    func uninstallHelper() async throws {
        try await helperManager.uninstall()
        helperStatus = Self.resolveInstallationState(
            activeMethod: helperManager.activeMethod,
            isPendingApproval: helperManager.isPendingApproval,
            constants: sharedConstants
        )
    }

    /// 清理恢复弹窗状态。
    @MainActor
    func clearSMAppServiceRecoveryState() {
        smAppServiceRecoveryState = nil
    }

    /// 自动重装 SMAppService helper（先卸载后安装）。
    /// 仅用于 SMAppService XPC 异常的恢复路径。
    @MainActor
    func autoReinstallSMAppServiceHelper() async throws {
        guard !isAutoReinstallInProgress else {
            throw RouterError.helperRecoveryInProgress
        }

        guard helperManager.activeMethod == .smAppService else {
            throw RouterError.helperRecoveryFailed("当前 helper 并非由 SMAppService 管理")
        }

        isAutoReinstallInProgress = true
        smAppServiceRecoveryState = nil
        defer { isAutoReinstallInProgress = false }

        do {
            try await helperManager.forceUninstallWithAppleScriptForRecovery()
            helperStatus = Self.resolveInstallationState(
                activeMethod: helperManager.activeMethod,
                isPendingApproval: helperManager.isPendingApproval,
                constants: sharedConstants
            )
        } catch {
            throw RouterError.helperRecoveryFailed("强制卸载失败：\(error.localizedDescription)")
        }

        // osascript 强制卸载后等待系统状态传播，再进行安装。
        try? await Task.sleep(nanoseconds: 800_000_000)

        let firstInstallResult = try await installHelper(method: .smAppService)
        switch firstInstallResult {
        case .success:
            return
        case .failed(let error):
            // 对常见瞬态失败（Operation not permitted）进行一次延迟重试。
            if shouldRetrySMAppServiceInstall(after: error) {
                try? await Task.sleep(nanoseconds: 800_000_000)
                let secondInstallResult = try await installHelper(method: .smAppService)
                switch secondInstallResult {
                case .success:
                    return
                case .failed(let secondError):
                    throw RouterError.helperRecoveryFailed(recoveryInstallFailureMessage(from: secondError))
                }
            }

            throw RouterError.helperRecoveryFailed(recoveryInstallFailureMessage(from: error))
        }
    }

    // MARK: - Private Helpers

    /// 发送 RouteWriteRequest 并等待回复
    private func sendCommandWithReply(_ request: RouteWriteRequest) async throws -> RouteWriteReply {
        do {
            let selectedClient: XPCClient
            switch helperManager.activeMethod {
            case .smJobBless:
                selectedClient = jobBlessXPCClient
            case .smAppService:
                selectedClient = appServiceXPCClient
            case nil:
                throw RouterError.helperNotAvailable
            }

            return try await withCheckedThrowingContinuation { continuation in
                selectedClient.sendMessage(request, to: SharedConstant.commandRoute) { result in
                    switch result {
                    case .success(let reply):
                        continuation.resume(returning: reply)
                    case .failure(let error):
                        let routerError = RouterError.xpcError(error.localizedDescription)
                        self.maybePublishSMAppServiceRecovery(for: routerError)
                        continuation.resume(throwing: routerError)
                    }
                }
            }
        } catch let routerErr as RouterError {
            maybePublishSMAppServiceRecovery(for: routerErr)
            throw routerErr
        } catch {
            let routerError = RouterError.xpcError(error.localizedDescription)
            maybePublishSMAppServiceRecovery(for: routerError)
            throw routerError
        }
    }

    private func maybePublishSMAppServiceRecovery(for error: RouterError) {
        guard case .xpcError(let message) = error else { return }
        guard helperStatus == .installed else { return }
        guard helperManager.activeMethod == .smAppService else { return }
        guard !helperManager.isPendingApproval else { return }
        guard !isAutoReinstallInProgress else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.helperStatus == .installed else { return }
            guard self.helperManager.activeMethod == .smAppService else { return }
            guard !self.helperManager.isPendingApproval else { return }

            self.smAppServiceRecoveryState = SMAppServiceRecoveryState(
                errorMessage: message,
                canAutoReinstall: true
            )
        }
    }

    private func shouldRetrySMAppServiceInstall(after error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("operation not permitted") || message.contains("not permitted")
    }

    private func recoveryInstallFailureMessage(from error: Error) -> String {
        if shouldRetrySMAppServiceInstall(after: error) {
            return "安装失败：\(error.localizedDescription)。请确认应用位于 /Applications 且签名可用，然后重试。"
        }
        return "安装失败：\(error.localizedDescription)"
    }

    /// 发送 RouteWriteRequest 并将失败回复映射为 routeWriteFailed 错误
    private func sendCommand(_ request: RouteWriteRequest) async throws {
        let reply = try await sendCommandWithReply(request)
        if !reply.success {
            throw RouterError.routeWriteFailed(reply.errorMessage ?? "Unknown error")
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
    /// - 否则仅刷新 systemRoutes 快照（不触发 XPC 重新激活）
    @MainActor
    private func handleRouteEvent(destination: String, gateway: String, isAdd: Bool) {
        // 先刷新快照（非阻塞，读内存）
        systemRoutes = SystemRouteReader.readRoutes()

        // 查找匹配的 RouteRule（使用规范化目标地址）
        // systemRoutes 已经包含规范化的目标地址（SystemRouteReader 内部已调用 normalizeIPv4Destination）
        // 此处直接使用传入的 destination（来自内核消息，已规范化）与 rule.network 比较
        let normalizedDest = normalizeIPv4Destination(destination)

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

    /// Derives HelperToolInstallationState from PrivilegedHelperManager state.
    /// - For SMAppService: helper IS the bundled binary, so version always matches → .installed.
    /// - For SMJobBless: read version from the blessed binary and compare.
    private static func resolveInstallationState(
        activeMethod: InstallMethod?,
        isPendingApproval: Bool,
        constants: SharedConstant
    ) -> HelperToolInstallationState {
        switch activeMethod {
        case nil:
            if isPendingApproval {
                return .pendingActivation
            }
            return .notInstalled
        case .smAppService:
            // SMAppService uses the bundled binary. If approval is still pending,
            // expose explicit pendingActivation state instead of notInstalled.
            return isPendingApproval ? .pendingActivation : .installed
        case .smJobBless:
            do {
                let infoPropertyList = try HelperToolInfoPropertyList(from: constants.blessedLocation)
                let version = infoPropertyList.version
                if version < constants.helperToolVersion {
                    return .needUpgrade
                } else if version == constants.helperToolVersion {
                    return .installed
                } else {
                    return .notCompatible
                }
            } catch {
                return .notInstalled
            }
        }
    }
}
