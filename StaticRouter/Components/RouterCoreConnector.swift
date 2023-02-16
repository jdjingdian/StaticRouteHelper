//
//  RouterCoreConnector.swift
//  Static Router
//
//  Created by 经典 on 9/1/2023.
//

import Foundation
import SwiftUI

class RouterCoreConnector: ObservableObject {
    @Published private var netcore = RouterCore()

    init(){
        netcore.monitor.start(changeOccurred: updateInstallationStatus)
    }
    
    var helperState: HelperToolInstallationState {
        netcore.helperInstallState
    }
    
    //MARK: Users Intend
    
    func HelperToolAutoInstall(state: HelperToolInstallationState){
        switch state {
        case .notCompatible:
                //do reinstall
            InstallHelper(message: "Repair Helper to modify system route")
        case .needUpgrade:
            InstallHelper(message: "Upgrade Helper to modify system route")
        case .notInstalled:
            InstallHelper(message: "Install Helper to modify system route")
        case .installed:
            print("Helper already installed.")
        }
    }
    
    func InstallHelper(message: String){
        netcore.InstallHelper(InstallMessage: message)
    }
    
    func SendDebugMsg(){
        netcore.SendDebugCmd()
    }
    
    func ShowRoute(){
        netcore.ShowSystemRoute()
    }
    
    func SendUninstallCmd(){
        netcore.SendUninstallCmd()
    }
    
    func ModifyRoute(_ addToRoute: Bool, _ network: String, _ netmask: String, _ gateway: String, _ gatewayType: RouterCommand.GatewayType){
        netcore.ModifySystemRoute(addToRoute, network, netmask, gateway, gatewayType)
    }
    
    func CheckInstallState(){
        netcore.CheckInstallationState()
    }
    
    func updateInstallationStatus(_ status:HelperToolMonitor.InstallationStatus){
        print("monitor deteted changed")
        DispatchQueue.main.sync {
            //MARK: Back to main thread to refresh UI
            netcore.updateInstallationStatus(status)
        }
    }
    
}
