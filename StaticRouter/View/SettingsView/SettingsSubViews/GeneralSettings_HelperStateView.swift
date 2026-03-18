//
//  GeneralSettings_HelperStateView.swift
//  StaticRouteHelper
//

import Foundation
import SwiftUI
import ServiceManagement

struct GeneralSettings_HelperStateView: View {
    @EnvironmentObject private var routerService: RouterService

    // MARK: - State

    /// Controls the install method chooser sheet (macOS 14+ only).
    @State private var showChooser = false

    /// Controls the system settings guidance alert.
    @State private var showBackgroundSwitchAlert = false

    /// True immediately after an install completes, cleared once the pending-approval
    /// alert has been shown (or if approval is no longer needed).
    @State private var pendingApprovalAlertArmed = false

    /// Persisted user preference for install method (macOS 14+ only).
    @AppStorage("preferredInstallMethod") private var preferredInstallMethodRaw: String = "smAppService"

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(String(localized: "settings.helper.state.label"))
                    .font(.title3.bold())
                helperStateIcon
                Spacer()
                Button {
                    installOrUpgradeHelper()
                } label: {
                    Text(installButtonText)
                }
                .disabled(isInstallButtonDisabled)
                .buttonStyle(DefaultButtonStyle(
                    .buttonNeutral(.thin),
                    disable: Binding<Bool>(
                        get: { isInstallButtonDisabled },
                        set: { _ in }
                    )
                ))
            }
            Text(helperStateFooter)
                .font(.footnote.italic())
                .foregroundStyle(.secondary)

            // Active method text — shown below footer when helper is installed.
            if let methodText = activationMethodText {
                Text(methodText)
                    .font(.footnote.italic())
                    .foregroundStyle(.secondary)
            }
        }
        // Install method chooser sheet (macOS 14+ only; noop on 12–13 since showChooser stays false).
        .background(
            ChooserSheetPresenter(
                isPresented: $showChooser,
                preferredMethodRaw: $preferredInstallMethodRaw,
                onInstall: { method in
                    preferredInstallMethodRaw = method.rawStorageValue
                    showChooser = false
                    performInstall(method: method)
                },
                onCancel: { showChooser = false }
            )
        )
        // Background switch guidance alert.
        .alert(
            String(localized: "settings.helper.background_switch.alert.title"),
            isPresented: $showBackgroundSwitchAlert
        ) {
            Button(String(localized: "settings.helper.background_switch.alert.open_settings")) {
                if #available(macOS 13, *) {
                    SMAppService.openSystemSettingsLoginItems()
                }
            }
            Button(String(localized: "settings.helper.background_switch.alert.cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "settings.helper.background_switch.alert.message"))
        }
        // Post-install: show background switch alert if isPendingApproval becomes true
        // while the armed flag is set (i.e. we just performed an install).
        .onChange(of: routerService.helperManager.isPendingApproval) { newValue in
            if newValue && pendingApprovalAlertArmed {
                pendingApprovalAlertArmed = false
                showBackgroundSwitchAlert = true
            } else if !newValue {
                pendingApprovalAlertArmed = false
            }
        }
    }

    // MARK: - Computed Properties

    private var installButtonText: String {
        switch routerService.helperStatus {
        case .installed: return String(localized: "settings.helper.button.installed")
        case .pendingActivation: return String(localized: "settings.helper.button.pending_activation")
        case .needUpgrade: return String(localized: "settings.helper.button.upgrade")
        case .notCompatible: return String(localized: "settings.helper.button.repair")
        case .notInstalled: return String(localized: "settings.helper.button.install")
        }
    }

    private var isInstallButtonDisabled: Bool {
        switch routerService.helperStatus {
        case .installed, .pendingActivation:
            return true
        case .needUpgrade, .notCompatible, .notInstalled:
            return false
        }
    }

    private var helperStateFooter: String {
        switch routerService.helperStatus {
        case .installed:
            return String(localized: "settings.helper.footer.installed")
        case .pendingActivation:
            return String(localized: "settings.helper.footer.pending_activation")
        case .needUpgrade:
            return String(localized: "settings.helper.footer.needs_upgrade")
        case .notCompatible:
            return String(localized: "settings.helper.footer.not_compatible")
        case .notInstalled:
            return String(localized: "settings.helper.footer.not_installed")
        }
    }

    private var helperStateIcon: some View {
        switch routerService.helperStatus {
        case .installed:
            return Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
        case .pendingActivation:
            return Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.yellow)
        case .needUpgrade, .notCompatible:
            return Image(systemName: "exclamationmark.circle.fill").foregroundColor(.yellow)
        case .notInstalled:
            return Image(systemName: "x.circle.fill").foregroundColor(.red)
        }
    }

    /// Returns a localized string describing the active installation method.
    /// Only non-nil when helper is installed or pending activation.
    private var activationMethodText: String? {
        switch routerService.helperStatus {
        case .installed, .pendingActivation:
            break
        case .needUpgrade, .notCompatible, .notInstalled:
            return nil
        }

        if routerService.helperManager.isPendingApproval {
            return String(localized: "settings.helper.footer.installed.method.pending_approval")
        }

        switch routerService.helperManager.activeMethod {
        case .smAppService:
            return String(localized: "settings.helper.footer.installed.method.smappservice")
        case .smJobBless:
            return String(localized: "settings.helper.footer.installed.method.smjobbless")
        case nil:
            return nil
        }
    }

    // MARK: - Actions

    /// Entry point for install button tap.
    private func installOrUpgradeHelper() {
        if #available(macOS 14, *) {
            // macOS 14+: show method chooser sheet
            showChooser = true
        } else {
            // macOS 12–13: directly install via SMJobBless
            performInstall(method: .smJobBless)
        }
    }

    /// Execute the actual install for the given method, with background switch pre-check.
    private func performInstall(method: InstallMethod) {
        if #available(macOS 14, *), method == .smAppService {
            // Pre-check: if background switch is definitely off, guide user first
            if routerService.helperManager.isBackgroundSwitchOff() {
                showBackgroundSwitchAlert = true
                return
            }
        }
        // Arm the pending-approval watch so we can show the alert if the background
        // switch turns out to be off after the install completes (detected via polling).
        pendingApprovalAlertArmed = true
        Task {
            do {
                _ = try await routerService.installHelper(method: method)
            } catch {
                pendingApprovalAlertArmed = false
                // Errors surface via helperStatus; no-op here
            }
        }
    }
}
