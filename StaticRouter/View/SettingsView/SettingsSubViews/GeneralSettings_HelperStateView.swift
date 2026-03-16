//
//  GeneralSettings_HelperStateView.swift
//  StaticRouteHelper
//

import Foundation
import SwiftUI

struct GeneralSettings_HelperStateView: View {
    @Environment(RouterService.self) private var routerService

    var body: some View {
        HStack {
            Text("Privileged Helper State: ")
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
        case .installed: return "Already Installed"
        case .needUpgrade: return "Upgrade"
        case .notCompatible: return "Repair"
        case .notInstalled: return "Install"
        }
    }

    private var helperStateFooter: String {
        switch routerService.helperStatus {
        case .installed:
            return "Helper already installed, now you can modify system routes at ease"
        case .needUpgrade:
            return "Helper already installed but not the latest version, it is recommended to upgrade it"
        case .notCompatible:
            return "Helper already installed but version may not be compatible, it is recommended to reinstall it"
        case .notInstalled:
            return "Need to install Helper, route command needs privilege to process"
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
