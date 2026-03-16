//
//  GeneralSettingsView.swift
//  StaticRouteHelper
//

import Foundation
import SwiftUI

struct GeneralSettingsView: View {
    @Environment(RouterService.self) private var routerService
    @State private var showUninstallAlert = false

    var body: some View {
        VStack(alignment: .leading) {
            GeneralSettings_HelperStateView()
            PaddedDivider(padding: nil)
            HStack {
                Spacer()
                uninstallButton
            }
        }
        .padding()
    }

    private var uninstallButton: some View {
        Button {
            showUninstallAlert = true
        } label: {
            Text(String(localized: "settings.helper.uninstall.button"))
        }
        .buttonStyle(DefaultButtonStyle(
            .buttonDestory(.small),
            disable: Binding<Bool>(
                get: { routerService.helperStatus == .notInstalled },
                set: { _, _ in }
            )
        ))
        .disabled(routerService.helperStatus == .notInstalled)
        .alert(isPresented: $showUninstallAlert) {
            Alert(
                title: Text(String(localized: "settings.helper.uninstall.alert.title")),
                message: Text(String(localized: "settings.helper.uninstall.alert.message")),
                primaryButton: .default(Text(String(localized: "settings.helper.uninstall.alert.confirm"))) {
                    Task {
                        try? await routerService.uninstallHelper()
                    }
                },
                secondaryButton: .default(Text(String(localized: "settings.helper.uninstall.alert.cancel")))
            )
        }
    }
}
