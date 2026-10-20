//
//  RouterService.swift
//  StaticRouteHelper
//

import Foundation
import Combine
import AppKit
import Network
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
    /// 路由表可能与应用状态失配（事件丢失 / 网络变化），需要全量对账 isActive。
    static let routeTableNeedsRecalibration = Notification.Name("cn.magicdian.staticrouter.routeTableNeedsRecalibration")
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
    /// 网络路径监听（拔插网线 / 切换 Wi-Fi 时触发对账）
    private var networkPathMonitor: NWPathMonitor?
    /// 网络变化对账的防抖任务
    private var recalibrationDebounceTask: Task<Void, Never>?

    /// Combine subscriptions for helperManager state propagation.
    private var helperManagerCancellables = Set<AnyCancellable>()
    /// Fallback polling when helper monitor cannot create filesystem watchers.
    private var helperStatusFallbackPollingCancellable: AnyCancellable?
    private var appDidBecomeActiveCancellable: AnyCancellable?
    private let helperStatusFallbackInterval: TimeInterval = 10
    private var isHelperStatusFallbackEnabled = false

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
        let monitorStartReport = helperMonitor.start { [weak self] _ in
            guard let self else { return }
            self.refreshHelperStatusFromManager()
        }
        if monitorStartReport.isDegraded {
            enableHelperStatusFallbackPolling()
        }
        observeAppActivationForHelperStatusRefresh()

        // Propagate helperManager state changes (from didBecomeActive / Timer monitoring)
        // to helperStatus so the UI reflects switch state changes in real time.
        helperManager.$activeMethod
            .combineLatest(helperManager.$isPendingApproval)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (activeMethod, isPendingApproval) in
                guard let self else { return }
                let nextState = Self.resolveInstallationState(
                    activeMethod: activeMethod,
                    isPendingApproval: isPendingApproval,
                    constants: self.sharedConstants
                )
                if self.helperStatus != nextState {
                    self.helperStatus = nextState
                }
            }
            .store(in: &helperManagerCancellables)

        // 启动 PF_ROUTE 实时监听
        startRouteMonitor()
        // 网络变化（拔插网线 / 切换接口）时主动对账（issue #20）
        startNetworkPathMonitor()
    }

    deinit {
        helperMonitor.stop()
        helperStatusFallbackPollingCancellable?.cancel()
        appDidBecomeActiveCancellable?.cancel()
        monitoringTask?.cancel()
        networkPathMonitor?.cancel()
        recalibrationDebounceTask?.cancel()
    }

    /// 操作失败后将单条规则的 isActive 校准到真实状态（避免开关卡在错误显示）。
    @available(macOS 14, *)
    @MainActor
    func reconcileActiveState(for rule: RouteRule) {
        RouteStateCalibrator.calibrate(rules: [rule], systemRoutes: SystemRouteReader.readRoutes())
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
            context.saveOrLog(operation: "activateRouteMO")
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
            context.saveOrLog(operation: "deactivateRouteMO")
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

    /// Refreshes helper manager state and safely updates helperStatus on the main queue.
    private func refreshHelperStatusFromManager() {
        helperManager.refreshState()
        let nextState = Self.resolveInstallationState(
            activeMethod: helperManager.activeMethod,
            isPendingApproval: helperManager.isPendingApproval,
            constants: sharedConstants
        )
        DispatchQueue.main.async {
            if self.helperStatus != nextState {
                self.helperStatus = nextState
            }
        }
    }

    private func enableHelperStatusFallbackPolling() {
        guard !isHelperStatusFallbackEnabled else { return }
        isHelperStatusFallbackEnabled = true

        // Run one immediate refresh so the UI is updated without waiting a full polling interval.
        refreshHelperStatusFromManager()

        helperStatusFallbackPollingCancellable = Timer.publish(
            every: helperStatusFallbackInterval,
            on: .main,
            in: .common
        )
        .autoconnect()
        .sink { [weak self] _ in
            self?.refreshHelperStatusFromManager()
        }
    }

    private func observeAppActivationForHelperStatusRefresh() {
        appDidBecomeActiveCancellable = NotificationCenter.default
            .publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.isHelperStatusFallbackEnabled else { return }
                self.refreshHelperStatusFromManager()
            }
    }

    // MARK: - PF_ROUTE Monitor

    /// 启动后台 PF_ROUTE socket 监听循环，订阅 RTM_ADD / RTM_DELETE 事件，
    /// 自动同步受影响 RouteRule 的 isActive 状态到内存（不触发 XPC 重新激活）。
    private func startRouteMonitor() {
        monitoringTask = Task.detached(priority: .background) { [weak self] in
            var buf = [UInt8](repeating: 0, count: 4096)

            // 外层循环：socket 出现致命错误时重建，而不是永久退出。
            // 历史实现（issue #20）中任何 read 失败都会跳出循环且不再重启，
            // 导致网络波动后 isActive 永久失配。
            while !Task.isCancelled {
                // 打开 PF_ROUTE raw socket（不需要 root 权限）
                let sock = socket(PF_ROUTE, SOCK_RAW, AF_UNSPEC)
                guard sock >= 0 else {
                    AppLog.persistence.error("[RouteMonitor] 无法打开 PF_ROUTE socket：\(String(cString: strerror(errno)), privacy: .public)")
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    continue
                }

                // 扩大接收缓冲：拔插网线时事件风暴（接口 + 路由 + ARP 条目变化）
                // 很容易撑爆默认缓冲（约 8KB），丢事件会让状态收敛退化到
                // "防抖对账"路径（1.5s+），而 RTM_DELETE 即时同步本可毫秒级生效
                var rcvbuf: Int32 = 1 << 20 // 1MB
                if setsockopt(sock, SOL_SOCKET, SO_RCVBUF, &rcvbuf, socklen_t(MemoryLayout<Int32>.size)) != 0 {
                    AppLog.persistence.info("[RouteMonitor] 扩大接收缓冲失败（不影响功能）：\(String(cString: strerror(errno)), privacy: .public)")
                }

                while !Task.isCancelled {
                    let n = read(sock, &buf, buf.count)
                    if n < 0 {
                        let err = errno
                        if err == EINTR { continue }
                        if err == ENOBUFS {
                            // 拔插网线时路由事件风暴会撑爆接收缓冲，部分事件丢失——
                            // 用全量对账补偿，socket 本身仍然可用
                            AppLog.persistence.info("[RouteMonitor] 接收缓冲溢出（ENOBUFS），部分事件丢失，触发对账")
                            await self?.postRecalibration(reason: "eventBufferOverflow")
                            continue
                        }
                        AppLog.persistence.error("[RouteMonitor] read 失败（errno=\(err)）：\(String(cString: strerror(err)), privacy: .public)，重建 socket")
                        break
                    }
                    if Task.isCancelled { break }
                    guard n >= MemoryLayout<rt_msghdr>.size else { continue }

                    let header: rt_msghdr = buf.withUnsafeBytes { ptr in
                        ptr.load(fromByteOffset: 0, as: rt_msghdr.self)
                    }

                    switch Int32(header.rtm_type) {
                    case RTM_ADD, RTM_DELETE:
                        break
                    case RTM_IFINFO:
                        // 接口 link 翻转：拔插网线的第一个信号，短防抖尽快收敛
                        await self?.postRecalibrationDebounced(reason: "interfaceLinkChange", interval: 300_000_000)
                        continue
                    case RTM_NEWADDR, RTM_DELADDR:
                        // 接口地址增删（拔线时 IPv4 被回收），与 IFINFO 成串出现
                        await self?.postRecalibrationDebounced(reason: "interfaceAddressChange")
                        continue
                    default:
                        continue
                    }

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

                close(sock)
                if !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
        }
    }

    @MainActor
    private func postRecalibrationDebounced(reason: String, interval: UInt64 = 1_500_000_000) {
        recalibrationDebounceTask = scheduleRecalibrationDebounced(
            reason: reason,
            previous: recalibrationDebounceTask,
            interval: interval
        )
    }

    /// 请求视图层对 isActive 做一次全量对账（与实际路由表比对并修正）。
    @MainActor
    private func postRecalibration(reason: String) async {
        await refreshSystemRoutes()
        NotificationCenter.default.post(name: .routeTableNeedsRecalibration, object: nil)
        AppLog.persistence.info("[RouteMonitor] 已请求 isActive 全量对账（\(reason, privacy: .public)）")
    }

    /// 监听系统网络路径变化（issue #20）：拔插网线、接口切换时内核会增删路由，
    /// 而 PF_ROUTE 事件可能丢失（缓冲溢出、接口型网关事件无法按网关匹配），
    /// 以主动对账兜底，保证开关状态自愈。
    private func startNetworkPathMonitor() {
        let monitor = NWPathMonitor()
        networkPathMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.scheduleRecalibrationAfterPathChange()
            }
        }
        monitor.start(queue: DispatchQueue(label: "cn.magicdian.staticrouter.pathmonitor", qos: .utility))
    }

    @MainActor
    private func scheduleRecalibrationAfterPathChange() {
        // 防抖：一次接口波动会触发多次 path 回调
        recalibrationDebounceTask = scheduleRecalibrationDebounced(
            reason: "networkPathChange",
            previous: recalibrationDebounceTask,
            interval: 1_500_000_000
        )
    }

    /// 对账防抖：接口波动会连发多个事件，合并为一次对账。
    /// interval 可按事件类型调整：RTM_IFINFO 是低频的 link 翻转事件，
    /// 用短防抖（300ms）让拔线后的开关状态尽快收敛（载波检测的硬件延迟
    /// 不可控）；地址增删与路径变化可能成串，用较长防抖合并。
    @MainActor
    private func scheduleRecalibrationDebounced(
        reason: String,
        previous: Task<Void, Never>?,
        interval: UInt64
    ) -> Task<Void, Never> {
        previous?.cancel()
        return Task { [weak self] in
            try? await Task.sleep(nanoseconds: interval)
            guard !Task.isCancelled else { return }
            guard let self else { return }
            await self.postRecalibration(reason: reason)
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
                } else if saFamily == AF_LINK, offset + MemoryLayout<sockaddr_dl>.size <= size {
                    // 接口型路由的网关是 AF_LINK，报告接口名（如 "en8"），
                    // 与 rule.gateway（接口名）匹配，否则这类规则的事件永远失配（issue #20）
                    gateway = Self.interfaceName(fromDl: buf, offset: offset)
                }
            default:
                break
            }

            // 内核路由报文 sockaddr 按 4 字节对齐；netmask 等 sockaddr 可能短于 16 字节
            let aligned = (saLen + 3) & ~3
            offset += max(aligned, 4)
        }

        guard let dest = destination else { return nil }
        return (dest, gateway)
    }

    /// 从 sockaddr_dl 中解析接口名（与 SystemRouteReader 保持一致）。
    /// 内核事件的 sockaddr_dl 通常只带 sdl_index 不带名字，需 if_indextoname 翻译。
    private static func interfaceName(fromDl buffer: [UInt8], offset: Int) -> String {
        guard offset + MemoryLayout<sockaddr_dl>.size <= buffer.count else { return "" }
        let sdl: sockaddr_dl = buffer.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: offset, as: sockaddr_dl.self)
        }
        let index = Int(sdl.sdl_index)
        if index > 0 {
            var nameBuf = [CChar](repeating: 0, count: Int(IF_NAMESIZE))
            if if_indextoname(UInt32(index), &nameBuf) != nil {
                return String(cString: nameBuf)
            }
        }
        let nlen = Int(sdl.sdl_nlen)
        guard nlen > 0 else { return "" }
        let nameOffset = offset + 8
        guard nameOffset + nlen <= buffer.count else { return "" }
        let nameBytes = buffer[nameOffset..<nameOffset + nlen]
        return String(bytes: nameBytes, encoding: .utf8) ?? ""
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
