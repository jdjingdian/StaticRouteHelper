//
//  PrivilegedHelperManager.swift
//  StaticRouter
//
//  Orchestration layer for privileged helper installation.
//  On macOS 14+: user explicitly selects SMAppService or SMJobBless at install time.
//  On macOS 12–13: uses SMJobBless exclusively.
//

import Foundation
import Combine
import AppKit
import SecureXPC
import Blessed
import Authorized
import ServiceManagement
import OSLog

// MARK: - PrivilegedHelperManager

/// Single authority for privileged helper install strategy, state detection, and lifecycle.
/// Uses ObservableObject so it works with @StateObject / @EnvironmentObject on macOS 12+.
final class PrivilegedHelperManager: ObservableObject {

    // MARK: - Logger

    private let logger = Logger(subsystem: "cn.magicdian.staticrouter", category: "helper-management")

    // MARK: - Published State

    /// The currently active installation method, derived from live system state.
    @Published private(set) var activeMethod: InstallMethod?

    /// True when SMAppService registration has been submitted but not yet approved by the user
    /// (macOS 14+ only; always false on macOS 12–13).
    @Published private(set) var isPendingApproval: Bool = false

    // MARK: - Computed Properties

    /// Ordered list of installation methods available on the current OS.
    /// The first element is the most preferred method.
    var supportedMethods: [InstallMethod] {
        if #available(macOS 14, *) {
            return [.smAppService, .smJobBless]
        } else {
            return [.smJobBless]
        }
    }

    // MARK: - Private

    private let constants: SharedConstant
    private let xpcClient: XPCClient

    /// Combine subscriptions for state monitoring (macOS 14+ only).
    private var cancellables = Set<AnyCancellable>()

    /// Baseline low-frequency polling subscription (macOS 14+).
    private var baselinePollingCancellable: AnyCancellable?

    /// Short-lived high-frequency polling subscription after install success.
    private var installBurstPollingCancellable: AnyCancellable?

    /// Cancel token for ending the install burst polling window.
    private var installBurstStopWorkItem: DispatchWorkItem?

    private let baselinePollingInterval: TimeInterval = 10
    private let installBurstPollingInterval: TimeInterval = 0.5
    private let installBurstDuration: TimeInterval = 3
    private let uninstallXPCTimeout: TimeInterval = 3
    private let installSettleTimeout: TimeInterval = 8
    private let installSettlePollInterval: TimeInterval = 0.25
    private let uninstallSettleTimeout: TimeInterval = 5
    private let uninstallSettlePollInterval: TimeInterval = 0.25

    // MARK: - Init

    init(constants: SharedConstant) {
        self.constants = constants
        self.xpcClient = XPCClient.forMachService(named: constants.jobBlessMachServiceName)
        refreshState()
        startStateMonitoring()
    }

    // MARK: - State Monitoring

    /// Starts background switch state monitoring (macOS 14+ only).
    /// Uses two mechanisms:
    ///   1. didBecomeActiveNotification — catches "user went to System Settings and came back"
    ///   2. Baseline timer every 10s — catches changes while app stays in foreground (split-screen etc.)
    private func startStateMonitoring() {
        guard #available(macOS 14, *) else { return }

        // 1. Refresh on app becoming active
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshState()
            }
            .store(in: &cancellables)

        // 2. Baseline low-frequency timer poll (10s) while app is running
        startBaselinePolling()
    }

    private func startBaselinePolling() {
        baselinePollingCancellable?.cancel()
        baselinePollingCancellable = makePollingCancellable(every: baselinePollingInterval)
    }

    private func makePollingCancellable(every interval: TimeInterval) -> AnyCancellable {
        Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshState()
            }
    }

    /// Starts a short high-frequency polling window after install/uninstall succeeds.
    /// This bridges delays in observable system-state updates.
    private func startStateBurstPollingWindow() {
        guard #available(macOS 14, *) else { return }

        installBurstPollingCancellable?.cancel()
        installBurstStopWorkItem?.cancel()

        logger.info("Starting helper-state burst polling (interval: \(self.installBurstPollingInterval, privacy: .public)s, duration: \(self.installBurstDuration, privacy: .public)s)")

        // Immediate refresh first, then continue with short-interval polling.
        refreshState()
        installBurstPollingCancellable = makePollingCancellable(every: installBurstPollingInterval)

        let stopWorkItem = DispatchWorkItem { [weak self] in
            self?.stopInstallBurstPollingWindow()
        }
        installBurstStopWorkItem = stopWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + installBurstDuration, execute: stopWorkItem)
    }

    private func stopInstallBurstPollingWindow() {
        installBurstPollingCancellable?.cancel()
        installBurstPollingCancellable = nil
        installBurstStopWorkItem?.cancel()
        installBurstStopWorkItem = nil
        logger.info("Helper-state burst polling ended; baseline polling remains active")
    }

    // MARK: - State Refresh

    /// Re-derives `activeMethod` and `isPendingApproval` from live system state.
    /// Call after install/uninstall and on app launch.
    func refreshState() {
        let previousMethod = activeMethod
        let previousPending = isPendingApproval

        if #available(macOS 14, *) {
            refreshState14()
        } else {
            refreshStateLegacy()
        }

        // Log state changes
        if activeMethod != previousMethod {
            let prev = previousMethod.map { "\($0)" } ?? "nil"
            let curr = activeMethod.map { "\($0)" } ?? "nil"
            logger.info("Helper state changed: \(prev, privacy: .public) → \(curr, privacy: .public)")
        }
        if isPendingApproval != previousPending {
            if isPendingApproval {
                logger.info("Background switch state changed: pending approval detected")
            } else {
                logger.info("Background switch state changed: pending approval cleared")
            }
        }
    }

    @available(macOS 14, *)
    private func refreshState14() {
        // Check SMJobBless FIRST: if a blessed helper is registered with launchd as a
        // standalone process, that takes precedence over SMAppService.status, which can
        // remain .enabled from a previous (possibly unregistered) SMAppService registration.
        if isInstalledViaJobBless() {
            activeMethod = .smJobBless
            isPendingApproval = false
            return
        }

        // No SMJobBless process — check SMAppService.
        let service = SMAppService.daemon(plistName: "\(constants.appServiceLabel).plist")
        switch service.status {
        case .enabled:
            activeMethod = .smAppService
            isPendingApproval = false
        case .requiresApproval:
            activeMethod = .smAppService
            isPendingApproval = true
        default:
            activeMethod = nil
            isPendingApproval = false
        }
    }

    private func refreshStateLegacy() {
        isPendingApproval = false
        if isInstalledViaJobBless() {
            activeMethod = .smJobBless
        } else {
            activeMethod = nil
        }
    }

    /// Returns true if the helper binary is present at its blessed location
    /// AND is registered with launchd (guarding against leftover binaries).
    private func isInstalledViaJobBless() -> Bool {
        // In practice `launchctl print system/<label>` can return "not found"
        // for on-demand jobs even when SMJobBless artifacts are present and callable.
        // Use the blessed artifacts as the source of truth after separating labels.
        let binaryExists = FileManager.default.fileExists(atPath: constants.blessedLocation.path)
        let plistExists = FileManager.default.fileExists(atPath: constants.blessedPropertyListLocation.path)
        return binaryExists && plistExists
    }

    // MARK: - Background Switch Check (macOS 14+)

    /// Returns true if the background switch is definitely OFF (SMAppService status is .requiresApproval).
    /// Returns false for all other states (enabled, not registered, or unknown).
    @available(macOS 14, *)
    func isBackgroundSwitchOff() -> Bool {
        let service = SMAppService.daemon(plistName: "\(constants.appServiceLabel).plist")
        
        return service.status == .requiresApproval
    }

    // MARK: - install(method:)

    /// Installs the helper using the specified method.
    /// - On macOS 14+: executes either SMAppService or SMJobBless based on `method`.
    /// - On macOS 12–13: always uses SMJobBless regardless of `method`.
    @MainActor
    func install(method: InstallMethod) async throws -> InstallResult {
        logger.info("Installing helper via \(method == .smAppService ? "SMAppService" : "SMJobBless", privacy: .public)")

        let result: InstallResult
        if #available(macOS 14, *), method == .smAppService {
            result = try await installViaAppService()
        } else {
            result = try await installViaJobBless()
        }

        switch result {
        case .success(let m):
            logger.info("Helper installed successfully via \(m == .smAppService ? "SMAppService" : "SMJobBless", privacy: .public)")
            startStateBurstPollingWindow()
        case .failed(let error):
            logger.error("Helper installation failed: \(error.localizedDescription, privacy: .public)")
        }

        return result
    }

    @available(macOS 14, *)
    @MainActor
    private func installViaAppService() async throws -> InstallResult {
        let service = SMAppService.daemon(plistName: "\(constants.appServiceLabel).plist")
        do {
            try service.register()
            refreshState()
            return .success(method: .smAppService)
        } catch {
            refreshState()
            return .failed(error: error)
        }
    }

    /// SMJobBless installation (macOS 12–13 primary path, and macOS 14+ user choice).
    @MainActor
    private func installViaJobBless() async throws -> InstallResult {
        await cleanupSMAppServiceRegistrationIfAny(reason: "before SMJobBless install")

        do {
            try await PrivilegedHelperManager._blessedShared.authorizeAndBless(
                message: "Install Helper to modify system route",
                icon: nil
            )

            await cleanupSMAppServiceRegistrationIfAny(reason: "after SMJobBless install")

            let verification = await waitForJobBlessInstallToSettle()
            switch verification {
            case .succeeded:
                return .success(method: .smJobBless)
            case .conflictingSMAppService:
                logger.error("SMJobBless install conflict: system job became SMAppService-submitted")
                return .failed(error: PrivilegedHelperError.conflictingServiceRegistration)
            case .timedOut:
                logger.error("SMJobBless install verification failed: state did not settle within timeout")
                return .failed(error: PrivilegedHelperError.smJobBlessVerificationFailed)
            }
        } catch AuthorizationError.canceled {
            return .failed(error: AuthorizationError.canceled)
        } catch {
            return .failed(error: error)
        }
    }

    @MainActor
    private func waitForJobBlessInstallToSettle() async -> JobBlessInstallVerification {
        let deadline = Date().addingTimeInterval(installSettleTimeout)

        while Date() < deadline {
            refreshState()

            if activeMethod == .smJobBless {
                return .succeeded
            }

            if isSMAppServiceSubmittedSystemJobPresent() || activeMethod == .smAppService {
                return .conflictingSMAppService
            }

            let sleepNs = UInt64(installSettlePollInterval * 1_000_000_000)
            try? await Task.sleep(nanoseconds: sleepNs)
        }

        refreshState()
        if activeMethod == .smAppService || isSMAppServiceSubmittedSystemJobPresent() {
            return .conflictingSMAppService
        }
        return .timedOut
    }

    // MARK: - uninstall()

    /// Recovery-only path: force uninstall helper via AppleScript, regardless of current method details.
    /// Used when SMAppService is installed but XPC becomes unreachable after updates.
    @MainActor
    func forceUninstallWithAppleScriptForRecovery() async throws {
        logger.info("Force-uninstalling helper via osascript for recovery")
        try await uninstallForciblyWithAppleScript()
        refreshState()
        startStateBurstPollingWindow()
    }

    /// Uninstalls the helper using the path matching `activeMethod`.
    @MainActor
    func uninstall() async throws {
        logger.info("Uninstalling helper (activeMethod: \(self.activeMethod.map { "\($0)" } ?? "nil", privacy: .public))")

        // Always refresh state at the end, even if an error is thrown.
        defer { refreshState() }

        switch activeMethod {
        case .smAppService:
            if #available(macOS 14, *) {
                if isPendingApproval, isBackgroundSwitchOff() {
                    logger.info("Uninstalling pending-approval helper via osascript path")
                    try await uninstallForciblyWithAppleScript()
                } else {
                    let service = SMAppService.daemon(plistName: "\(constants.appServiceLabel).plist")
                    try await service.unregister()
                    logger.info("Helper unregistered via SMAppService")
                }
            }

        case .smJobBless:
            logger.info("Uninstalling helper (SMJobBless) via XPC")
            do {
                try await sendUninstallRequestWithTimeout()
                logger.info("Helper XPC uninstall request completed successfully")
            } catch {
                logger.warning("XPC uninstall failed (\(error.localizedDescription, privacy: .public)); trying forced removal via osascript")
                try await uninstallForciblyWithAppleScript()
                startStateBurstPollingWindow()
                return
            }

            let settled = await waitForJobBlessUninstallToSettle()
            if settled {
                logger.info("SMJobBless uninstall state settled after XPC request")
            } else {
                logger.warning("SMJobBless uninstall did not settle in \(self.uninstallSettleTimeout, privacy: .public)s; falling back to osascript")
                try await uninstallForciblyWithAppleScript()
            }

        case nil:
            logger.info("Uninstall called but no active method — no-op")
        }

        startStateBurstPollingWindow()
    }

    /// Sends uninstall route to helper and fails fast if no reply arrives.
    /// Some failure modes can leave the XPC request hanging without an immediate error,
    /// so we enforce a timeout and fall back to AppleScript-based removal.
    @MainActor
    private func sendUninstallRequestWithTimeout() async throws {
        logger.info("Sending helper XPC uninstall request with timeout \(self.uninstallXPCTimeout, privacy: .public)s")

        try await withCheckedThrowingContinuation { continuation in
            let lock = NSLock()
            var finished = false

            let finish: (Result<Void, Error>) -> Void = { result in
                lock.lock()
                defer { lock.unlock() }
                guard !finished else { return }
                finished = true
                switch result {
                case .success:
                    continuation.resume(returning: ())
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            let timeoutWorkItem = DispatchWorkItem {
                finish(.failure(PrivilegedHelperError.xpcUninstallTimedOut(self.uninstallXPCTimeout)))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + uninstallXPCTimeout, execute: timeoutWorkItem)

            xpcClient.send(to: SharedConstant.uninstallRoute) { response in
                timeoutWorkItem.cancel()
                switch response {
                case .success:
                    finish(.success(()))
                case .failure(let error):
                    finish(.failure(error))
                }
            }
        }
    }

    /// Waits briefly for SMJobBless uninstall side-effects to become observable.
    /// Returns true once helper binary/launchd state is gone; false on timeout.
    @MainActor
    private func waitForJobBlessUninstallToSettle() async -> Bool {
        let deadline = Date().addingTimeInterval(uninstallSettleTimeout)
        while Date() < deadline {
            refreshState()
            if !isInstalledViaJobBless() {
                return true
            }
            let sleepNs = UInt64(uninstallSettlePollInterval * 1_000_000_000)
            try? await Task.sleep(nanoseconds: sleepNs)
        }
        return false
    }

    /// Fallback uninstall path using AppleScript when normal uninstall is unavailable.
    /// Uses `osascript` to run launchctl + rm with administrator privileges.
    @MainActor
    private func uninstallForciblyWithAppleScript() async throws {
        let plist = constants.blessedPropertyListLocation.path
        let binary = constants.blessedLocation.path
        let label = constants.helperToolLabel

        // Build shell commands: unload the daemon, then delete plist and binary.
        // Escape paths for shell (they're fixed system paths, so no special chars expected).
        let shellScript = "launchctl unload '\(plist)'; rm -f '\(plist)' '\(binary)'"
        let appleScript = "do shell script \"\(shellScript)\" with administrator privileges"

        logger.info("Forced removal via osascript: \(shellScript, privacy: .public)")

        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", appleScript]
        let pipe = Pipe()
        task.standardError = pipe
        task.launch()
        task.waitUntilExit()

        if task.terminationStatus != 0 {
            let errData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errMsg = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown error"
            logger.error("Forced removal failed (exit \(task.terminationStatus)): \(errMsg, privacy: .public)")
            throw PrivilegedHelperError.forcedRemovalFailed(errMsg)
        }
        logger.info("Forced removal succeeded for \(label, privacy: .public)")

        // After removing the binary and plist, also clean up any lingering SMAppService
        // registration. When SMJobBless was previously active alongside an old SMAppService
        // registration, `SMAppService.status` can still return `.enabled` after the binary
        // is deleted — launchd retains a record until `unregister()` is called explicitly.
        // Ignoring errors here: if it was never registered via SMAppService, unregister() is a no-op.
        if #available(macOS 13, *) {
            let service = SMAppService.daemon(plistName: "\(constants.appServiceLabel).plist")
            do {
                try await service.unregister()
                logger.info("SMAppService registration cleaned up after forced removal")
            } catch {
                logger.warning("SMAppService unregister after forced removal (ignored): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    @MainActor
    private func cleanupSMAppServiceRegistrationIfAny(reason: String) async {
        guard #available(macOS 13, *) else { return }

        let service = SMAppService.daemon(plistName: "\(constants.appServiceLabel).plist")
        let status = service.status
        guard status != .notRegistered else { return }

        logger.info("Cleaning SMAppService registration (reason: \(reason, privacy: .public), status: \(String(describing: status), privacy: .public))")

        do {
            try await service.unregister()
            logger.info("SMAppService registration cleanup succeeded (reason: \(reason, privacy: .public))")
        } catch {
            logger.warning("SMAppService registration cleanup failed (reason: \(reason, privacy: .public)): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func runLaunchctl(_ arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        process.launchPath = "/bin/launchctl"
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.launch()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return (process.terminationStatus, output)
    }

    private func isSMAppServiceSubmittedSystemJobPresent() -> Bool {
        let result = runLaunchctl(["print", "system/\(constants.appServiceLabel)"])
        guard result.status == 0 else { return false }

        let bundleProgramMarker = "Contents/Library/LaunchServices/\(constants.helperToolLabel)"
        return result.output.contains("submitted by smd") || result.output.contains(bundleProgramMarker)
    }

    private enum JobBlessInstallVerification {
        case succeeded
        case conflictingSMAppService
        case timedOut
    }

    enum PrivilegedHelperError: LocalizedError {
        case forcedRemovalFailed(String)
        case xpcUninstallTimedOut(TimeInterval)
        case conflictingServiceRegistration
        case smJobBlessVerificationFailed
        var errorDescription: String? {
            switch self {
            case .forcedRemovalFailed(let msg):
                return "Uninstall failed: \(msg)"
            case .xpcUninstallTimedOut(let seconds):
                return "Uninstall request timed out after \(seconds)s"
            case .conflictingServiceRegistration:
                return "SMJobBless install conflict: SMAppService registration is still active"
            case .smJobBlessVerificationFailed:
                return "SMJobBless install did not become active"
            }
        }
    }

    // MARK: - Blessed package accessor (avoids name collision with this class)

    /// Accessor for the `Blessed` package's `PrivilegedHelperManager.shared` singleton,
    /// referenced under a different name to avoid collision with this orchestration class.
    private static let _blessedShared = Blessed.PrivilegedHelperManager.shared
}
