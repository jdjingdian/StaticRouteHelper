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

    // MARK: - Init

    init(constants: SharedConstant) {
        self.constants = constants
        self.xpcClient = XPCClient.forMachService(named: constants.machServiceName)
        refreshState()
        startStateMonitoring()
    }

    // MARK: - State Monitoring

    /// Starts background switch state monitoring (macOS 14+ only).
    /// Uses two mechanisms:
    ///   1. didBecomeActiveNotification — catches "user went to System Settings and came back"
    ///   2. Timer every 10s — catches changes while app stays in foreground (split-screen etc.)
    private func startStateMonitoring() {
        guard #available(macOS 14, *) else { return }

        // 1. Refresh on app becoming active
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshState()
            }
            .store(in: &cancellables)

        // 2. Low-frequency timer poll (10s) while app is running
        Timer.publish(every: 10, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshState()
            }
            .store(in: &cancellables)
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
            logger.info("Background switch state changed: isPendingApproval = \(self.isPendingApproval, privacy: .public)")
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
        let service = SMAppService.daemon(plistName: "\(constants.helperToolLabel).plist")
        switch service.status {
        case .enabled:
            activeMethod = .smAppService
            isPendingApproval = false
        case .requiresApproval:
            activeMethod = nil
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
        guard FileManager.default.fileExists(atPath: constants.blessedLocation.path) else {
            return false
        }
        let process = Process()
        process.launchPath = "/bin/launchctl"
        process.arguments = ["print", "system/\(constants.helperToolLabel)"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.launch()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    // MARK: - Background Switch Check (macOS 14+)

    /// Returns true if the background switch is definitely OFF (SMAppService status is .requiresApproval).
    /// Returns false for all other states (enabled, not registered, or unknown).
    @available(macOS 14, *)
    func isBackgroundSwitchOff() -> Bool {
        let service = SMAppService.daemon(plistName: "\(constants.helperToolLabel).plist")
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
        case .failed(let error):
            logger.error("Helper installation failed: \(error.localizedDescription, privacy: .public)")
        }

        return result
    }

    @available(macOS 14, *)
    @MainActor
    private func installViaAppService() async throws -> InstallResult {
        let service = SMAppService.daemon(plistName: "\(constants.helperToolLabel).plist")
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
        do {
            try await PrivilegedHelperManager._blessedShared.authorizeAndBless(
                message: "Install Helper to modify system route",
                icon: nil
            )
            refreshState()
            return .success(method: .smJobBless)
        } catch AuthorizationError.canceled {
            return .failed(error: AuthorizationError.canceled)
        } catch {
            return .failed(error: error)
        }
    }

    // MARK: - uninstall()

    /// Uninstalls the helper using the path matching `activeMethod`.
    @MainActor
    func uninstall() async throws {
        logger.info("Uninstalling helper (activeMethod: \(self.activeMethod.map { "\($0)" } ?? "nil", privacy: .public))")

        // Always refresh state at the end, even if an error is thrown.
        defer { refreshState() }

        switch activeMethod {
        case .smAppService:
            if #available(macOS 14, *) {
                let service = SMAppService.daemon(plistName: "\(constants.helperToolLabel).plist")
                try await service.unregister()
                logger.info("Helper unregistered via SMAppService")
            }

        case .smJobBless:
            logger.info("Uninstalling helper (SMJobBless) via XPC")
            do {
                try await xpcClient.send(to: SharedConstant.uninstallRoute)
                logger.info("Helper XPC uninstall request sent successfully")
            } catch {
                logger.warning("XPC uninstall failed (\(error.localizedDescription, privacy: .public)); trying forced removal via osascript")
                try await uninstallJobBlessForcibly()
            }

        case nil:
            logger.info("Uninstall called but no active method — no-op")
        }
    }

    /// Fallback SMJobBless uninstall when XPC is unavailable (e.g. debug build, crashed helper).
    /// Uses `osascript` to run launchctl + rm with administrator privileges.
    @MainActor
    private func uninstallJobBlessForcibly() async throws {
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
            let service = SMAppService.daemon(plistName: "\(label).plist")
            do {
                try await service.unregister()
                logger.info("SMAppService registration cleaned up after forced removal")
            } catch {
                logger.warning("SMAppService unregister after forced removal (ignored): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    enum PrivilegedHelperError: LocalizedError {
        case forcedRemovalFailed(String)
        var errorDescription: String? {
            switch self {
            case .forcedRemovalFailed(let msg):
                return "Uninstall failed: \(msg)"
            }
        }
    }

    // MARK: - Blessed package accessor (avoids name collision with this class)

    /// Accessor for the `Blessed` package's `PrivilegedHelperManager.shared` singleton,
    /// referenced under a different name to avoid collision with this orchestration class.
    private static let _blessedShared = Blessed.PrivilegedHelperManager.shared
}
