//
//  PrivilegedHelperManager.swift
//  StaticRouter
//
//  Orchestration layer for privileged helper installation.
//  On macOS 14+: attempts SMAppService first, falls back to SMJobBless on failure.
//  On macOS 12–13: uses SMJobBless exclusively.
//

import Foundation
import SecureXPC
import Blessed
import Authorized
import ServiceManagement

// MARK: - PrivilegedHelperManager

/// Single authority for privileged helper install strategy, state detection, and lifecycle.
/// Uses ObservableObject so it works with @StateObject / @EnvironmentObject on macOS 12+.
final class PrivilegedHelperManager: ObservableObject {

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

    /// True if the active method is the best available method (or not installed = false).
    var isOptimizedMode: Bool {
        guard let active = activeMethod else { return false }
        return active == supportedMethods.first
    }

    // MARK: - Private

    private let constants: SharedConstant
    private let xpcClient: XPCClient

    // MARK: - Init

    init(constants: SharedConstant) {
        self.constants = constants
        self.xpcClient = XPCClient.forMachService(named: constants.machServiceName)
        refreshState()
    }

    // MARK: - State Refresh

    /// Re-derives `activeMethod` and `isPendingApproval` from live system state.
    /// Call after install/uninstall and on app launch.
    func refreshState() {
        if #available(macOS 14, *) {
            refreshState14()
        } else {
            refreshStateLegacy()
        }
    }

    @available(macOS 14, *)
    private func refreshState14() {
        let service = SMAppService.daemon(plistName: "\(constants.helperToolLabel).plist")
        switch service.status {
        case .enabled:
            activeMethod = .smAppService
            isPendingApproval = false
        case .requiresApproval:
            activeMethod = nil
            isPendingApproval = true
        default:
            isPendingApproval = false
            // Secondary check: SMJobBless installed?
            if isInstalledViaJobBless() {
                activeMethod = .smJobBless
            } else {
                activeMethod = nil
            }
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

    // MARK: - install()

    /// Installs the helper.
    /// - On macOS 14+: tries SMAppService; returns `.smAppServiceFailedFallbackAvailable` if it fails.
    /// - On macOS 12–13: uses SMJobBless directly.
    @MainActor
    func install() async throws -> InstallResult {
        if #available(macOS 14, *) {
            return try await install14()
        } else {
            return try await installViaJobBless()
        }
    }

    @available(macOS 14, *)
    @MainActor
    private func install14() async throws -> InstallResult {
        let service = SMAppService.daemon(plistName: "\(constants.helperToolLabel).plist")
        do {
            try service.register()
            refreshState()
            return .success(method: .smAppService)
        } catch {
            return .smAppServiceFailedFallbackAvailable(error: error)
        }
    }

    /// SMJobBless installation (macOS 12–13 primary path, and macOS 14+ fallback).
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

    // MARK: - installFallback()

    /// Called after user confirms the fallback dialog (macOS 14+ only).
    /// Installs via SMJobBless and refreshes state.
    @MainActor
    func installFallback() async throws {
        let result = try await installViaJobBless()
        switch result {
        case .success:
            break // refreshState() already called inside installViaJobBless
        case .smAppServiceFailedFallbackAvailable(let error), .failed(let error):
            throw error
        }
    }

    // MARK: - upgrade()

    /// Migrates from SMJobBless to SMAppService (macOS 14+ only).
    ///
    /// Sequence:
    ///   1. Register via SMAppService.
    ///   2. On success: immediately send XPC `uninstallRoute` to the still-running SMJobBless
    ///      helper to trigger SelfUninstaller. The SMJobBless helper still owns the Mach service
    ///      name at this point, so the XPC message reliably reaches it before launchd switches over.
    ///   3. Refresh state — activeMethod should now be .smAppService.
    ///   4. On failure: do NOT send XPC; refresh state; rethrow.
    @available(macOS 14, *)
    @MainActor
    func upgrade() async throws {
        let service = SMAppService.daemon(plistName: "\(constants.helperToolLabel).plist")
        do {
            try service.register()
        } catch {
            refreshState()
            throw error
        }

        // SMAppService registration succeeded.
        // The SMJobBless helper is still alive — send XPC self-uninstall immediately.
        try? await xpcClient.send(to: SharedConstant.uninstallRoute)

        refreshState()
    }

    // MARK: - uninstall()

    /// Uninstalls the helper using the path matching `activeMethod`.
    @MainActor
    func uninstall() async throws {
        switch activeMethod {
        case .smAppService:
            if #available(macOS 14, *) {
                let service = SMAppService.daemon(plistName: "\(constants.helperToolLabel).plist")
                try await service.unregister()
            }

        case .smJobBless:
            try await xpcClient.send(to: SharedConstant.uninstallRoute)

        case nil:
            break // no-op
        }
        refreshState()
    }

    // MARK: - Blessed package accessor (avoids name collision with this class)

    /// Accessor for the `Blessed` package's `PrivilegedHelperManager.shared` singleton,
    /// referenced under a different name to avoid collision with this orchestration class.
    private static let _blessedShared = Blessed.PrivilegedHelperManager.shared
}
