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
            Text("Uninstall Helper")
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
                title: Text("Are you sure to uninstall helper?"),
                message: Text("After the uninstallation is complete, the system route cannot be modified by this tool."),
                primaryButton: .default(Text("Uninstall")) {
                    Task {
                        try? await routerService.uninstallHelper()
                    }
                },
                secondaryButton: .default(Text("Cancel"))
            )
        }
    }
}
