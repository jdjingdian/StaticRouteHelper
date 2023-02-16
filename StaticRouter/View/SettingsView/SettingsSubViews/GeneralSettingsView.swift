//
//  GeneralSettingsView.swift
//  Static Router
//
//  Created by 经典 on 14/1/2023.
//

import Foundation
import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var router: RouterCoreConnector
    @State private var showUinstallAlert = false
    
    var body: some View {
        VStack(alignment: .leading) {
            GeneralSettings_HelperStateView(router: router)
            PaddedDivider(padding: nil)
            HStack(){
                Text("Save Custom Route to iCloud")
                    .font(.title3.bold())
                Text("Not implement yet")
                    .font(.footnote.italic())
                    .foregroundColor(.secondary)
            }
            PaddedDivider(padding: nil)
            HStack(){
                Spacer()
                UninstallHelperButton()
            }
            
        }.padding()
    }
}

struct GeneralSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        GeneralSettingsView(router: RouterCoreConnector())
    }
}

extension GeneralSettingsView {
    fileprivate func UninstallHelperButton() -> some View {
        return Button {
            showUinstallAlert = true
        }label: {
            Text("Uninstall Helper")
        }.buttonStyle(DefaultButtonStyle(.buttonDestory(.small),disable: Binding<Bool>(
            get: { return router.helperState == .notInstalled },
            set: { _, _ in }))
        )
        .disabled(router.helperState == .notInstalled)
        .alert(isPresented: $showUinstallAlert) {
            return Alert(title: Text("Are you sure to uninstall helper?"),message: Text("After the uninstallation is complete, the system route cannot be modified by this tool."), primaryButton: .default(Text("Uninstall")){
                print("user try uninstall helper")
                router.SendUninstallCmd()
            }, secondaryButton: .default(Text("Cancel")){
                print("user cancel uninstall")
            })
        }
    }
}
