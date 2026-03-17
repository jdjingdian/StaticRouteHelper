//
//  GeneralSettings_HelperStateView.swift
//  StaticRouteHelper
//

import Foundation
import SwiftUI

struct GeneralSettings_HelperStateView: View {
    @EnvironmentObject private var routerService: RouterService

    // MARK: - Alert State

    /// Pending fallback error — set when SMAppService install fails and fallback is available.
    @State private var fallbackError: Error?

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
                .disabled(routerService.helperStatus == .installed)
                .buttonStyle(DefaultButtonStyle(
                    .buttonNeutral(.thin),
                    disable: Binding<Bool>(
                        get: { routerService.helperStatus == .installed },
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
        // SMAppService fallback confirmation alert.
        .alert(
            String(localized: "settings.helper.fallback.alert.title"),
            isPresented: Binding<Bool>(
                get: { fallbackError != nil },
                set: { if !$0 { fallbackError = nil } }
            )
        ) {
            Button(String(localized: "settings.helper.fallback.alert.confirm")) {
                fallbackError = nil
                Task {
                    try? await routerService.helperManager.installFallback()
                }
            }
            Button(String(localized: "settings.helper.fallback.alert.cancel"), role: .cancel) {
                fallbackError = nil
            }
        } message: {
            Text(String(localized: "settings.helper.fallback.alert.message"))
        }
    }

    // MARK: - Computed Properties

    private var installButtonText: String {
        switch routerService.helperStatus {
        case .installed: return String(localized: "settings.helper.button.installed")
        case .needUpgrade: return String(localized: "settings.helper.button.upgrade")
        case .notCompatible: return String(localized: "settings.helper.button.repair")
        case .notInstalled: return String(localized: "settings.helper.button.install")
        }
    }

    private var helperStateFooter: String {
        switch routerService.helperStatus {
        case .installed:
            return String(localized: "settings.helper.footer.installed")
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
        case .needUpgrade, .notCompatible:
            return Image(systemName: "exclamationmark.circle.fill").foregroundColor(.yellow)
        case .notInstalled:
            return Image(systemName: "x.circle.fill").foregroundColor(.red)
        }
    }

    /// Returns a localized string describing the active installation method,
    /// derived from `helperManager.activeMethod` (not OS version).
    /// Only non-nil when `helperStatus == .installed`.
    private var activationMethodText: String? {
        guard routerService.helperStatus == .installed else { return nil }

        // isPendingApproval: show distinct approval prompt instead of method name.
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

    private func installOrUpgradeHelper() {
        Task {
            do {
                let result = try await routerService.installHelper()
                switch result {
                case .success:
                    break // helperStatus updated inside installHelper()
                case .smAppServiceFailedFallbackAvailable(let error):
                    await MainActor.run { fallbackError = error }
                case .failed:
                    break // no fallback available; helperStatus stays unchanged
                }
            } catch {
                // Unexpected throw — ignore silently (errors visible via helperStatus).
            }
        }
    }
}
