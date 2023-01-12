//
//  ContentViewDev.swift
//  Static Router
//
//  Created by 经典 on 11/1/2023.
//

import Foundation
import SwiftUI
import SecureXPC
struct ContentViewDev: View{
    @ObservedObject var router:RouterCoreConnector
    @State var userDismissAlert: Bool = false
    var body: some View{
        VStack(){
            HStack(){
                Text("Install State: ")
                Text(bingHelperString.wrappedValue)
            }
            Button {
                router.CheckInstallState()
            } label: {
                Text("Check Install")
            }
            
            Button {
                router.SendDebugMsg()
            } label: {
                Text("Test Helper WHOAMI")
            }
            
            Button {
                router.ShowRoute()
            } label: {
                 Text("Show System route")
            }
            
            Button {
                router.ModifyRoute(true, "192.168.5.0", "255.255.255.0", "en0", .interface)
            } label: {
                Text("add 192.168.5.0")
            }
            
            Button {
                router.ModifyRoute(false, "192.168.5.0", "255.255.255.0", "en0", .interface)
            } label: {
                Text("del 192.168.5.0")
            }
            
            Button {
                router.InstallHelper(message: "ContentViewDev TEST")
            } label: {
                Text("Manual Install Helper")
            }
            
            Button {
                router.SendUninstallCmd()
            } label: {
                Text("Uninstall Helper")
            }

        }.padding(10).alert(isPresented: bindHelperAlert) {
            return Alert(title: Text("Privileged Helper Tool not installed!"),message: Text("The Static Route Helper need to be installed in order to modified system route."), primaryButton: .default(Text("Install")){
                print("user try install helper")
                router.InstallHelper(message: "ContentViewDev ALERT TEST"+"\n\n")
            }, secondaryButton: .default(Text("Cancel")){
                print("user cancel alert")
                self.userDismissAlert = true
                print(userDismissAlert)
            })
        }
    }
}


struct ContentViewDev_Previews:PreviewProvider{
    static var previews: some View {
        ContentViewDev(router: RouterCoreConnector())
    }
}


extension ContentViewDev {
    private var bingHelperString: Binding<String> {
        Binding {
            switch(router.helperState){
            case .notCompatible:
                return "Helper Not Compatible"
            case .needUpgrade:
                return "Helper Need Upgrade"
            case .installed:
                return "Helper Installed"
            case .notInstalled:
                return "Helper Not Installed"
            }
        } set: { Value in
            
        }
    }
    private var bindHelperAlert: Binding<Bool> {
        Binding {
            print(userDismissAlert)
            if userDismissAlert{
                return false
            }else{
                if router.helperState != .installed {
                    return true
                }else{
                    return false
                }
            }
        } set: { Value in
            
        }

    }
}
