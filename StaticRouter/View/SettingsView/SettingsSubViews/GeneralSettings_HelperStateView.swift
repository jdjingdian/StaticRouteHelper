//
//  GeneralSettings_HelperStateView.swift
//  StaticRouteHelper
//

import Foundation
import SwiftUI

struct GeneralSettings_HelperStateView: View {
    @EnvironmentObject private var routerService: RouterService

    var body: some View {
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
    }

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

    private func installOrUpgradeHelper() {
        try? routerService.installHelper()
    }
}
