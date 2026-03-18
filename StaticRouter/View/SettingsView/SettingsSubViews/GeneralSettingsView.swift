//
//  GeneralSettingsView.swift
//  StaticRouteHelper
//

import Foundation
import SwiftUI
import ServiceManagement

struct GeneralSettingsView: View {
    @EnvironmentObject private var routerService: RouterService
    @State private var showUninstallAlert = false
    @State private var showBackgroundSwitchAlert = false
    @State private var uninstallError: String? = nil
    @State private var showUninstallErrorAlert = false

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
        // Background switch guidance alert (shown when SMAppService uninstall is blocked).
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
        // Uninstall failure alert.
        .alert(
            String(localized: "settings.helper.uninstall.error.title"),
            isPresented: $showUninstallErrorAlert
        ) {
            Button(String(localized: "settings.helper.uninstall.error.ok"), role: .cancel) {}
        } message: {
            Text(uninstallError ?? "")
        }
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
                    performUninstall()
                },
                secondaryButton: .default(Text(String(localized: "settings.helper.uninstall.alert.cancel")))
            )
        }
    }

    private func performUninstall() {
        // For SMAppService uninstall on macOS 14+, check background switch state first.
        if #available(macOS 14, *),
           routerService.helperManager.activeMethod == .smAppService,
           routerService.helperManager.isBackgroundSwitchOff() {
            showBackgroundSwitchAlert = true
            return
        }
        Task {
            do {
                try await routerService.uninstallHelper()
            } catch {
                uninstallError = error.localizedDescription
                showUninstallErrorAlert = true
            }
        }
    }
}
