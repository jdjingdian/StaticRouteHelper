//
//  File.swift
//  Static Router
//
//  Created by 经典 on 14/1/2023.
//

import Foundation
import SwiftUI

struct GeneralSettings_HelperStateView: View{
    @ObservedObject var router: RouterCoreConnector
    var body: some View {
        HStack(){
            Text("Privileged Helper State: ")
                .font(.title3.bold())
            HelperInstallStateIcon(router.helperState)
            Spacer()
            Button {
                router.HelperToolAutoInstall(state: router.helperState)
            } label: {
                Text(HelperInstallButtonText(router.helperState))
            }.disabled(router.helperState == .installed)
                .buttonStyle(DefaultButtonStyle(.buttonNeutral(.thin),disable: Binding<Bool>(get: {
                    return router.helperState == .installed
                },set: { _ in
                    
                })))
        }
        Text(HelperInstallStateFooter(router.helperState))
            .font(.footnote.italic())
            .foregroundColor(.secondary)
    }
}
extension GeneralSettings_HelperStateView {
    private func HelperInstallButtonText(_ state: HelperToolInstallationState) -> String {
        if router.helperState == .installed {
            return "Already Installed"
        }else if router.helperState == .needUpgrade {
            return "Upgrade"
        }else if router.helperState == .notCompatible{
            return "Repair"
        }else{
            return "Install"
        }
    }
    
    private func HelperInstallStateText(_ state: HelperToolInstallationState) -> String {
        if router.helperState == .installed {
            return "Helper already installed"
        }else if router.helperState == .needUpgrade {
            return "Helper need upgrade"
        }else if router.helperState == .notCompatible{
            return "Helper need repair"
        }else{
            return "Need to install Helper"
        }
    }
    
    private func HelperInstallStateFooter(_ state: HelperToolInstallationState) -> String {
        if router.helperState == .installed {
            return "Helper already installed, now you can modify system routes at ease"
        }else if router.helperState == .needUpgrade {
            return "Helper already installed but not the latest version, it is recommand to upgrade it"
        }else if router.helperState == .notCompatible{
            return "Helper already installed but version may not compactible, it is recommand to reinstall it"
        }else{
            return "Need to install Helper, route command need privilege to process"
        }
    }
    
    private func HelperInstallStateIcon(_ state: HelperToolInstallationState) -> some View {
        if router.helperState == .installed {
            return Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
        }else if router.helperState == .needUpgrade {
            return Image(systemName: "exclamationmark.circle.fill").foregroundColor(.yellow)
        }else if router.helperState == .notCompatible{
            return Image(systemName: "exclamationmark.circle.fill").foregroundColor(.yellow)
        }else{
            return Image(systemName: "x.circle.fill").foregroundColor(.red)
        }
    }
}

struct GeneralSettings_HelperStateView_Previews: PreviewProvider {
    static var previews: some View {
        GeneralSettings_HelperStateView(router: RouterCoreConnector())
    }
}
