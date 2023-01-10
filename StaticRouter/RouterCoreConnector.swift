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
    
    func InstallHelper(message: String){
        netcore.InstallHelper(InstallMessage: message)
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
