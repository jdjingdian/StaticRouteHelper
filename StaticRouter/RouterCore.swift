//
//  RouterCore.swift
//  Static Router
//
//  Created by 经典 on 9/1/2023.
//

import Foundation
import Blessed
import SecureXPC
import Authorized
import SwiftUI


struct RouterCore {
    private (set) var helperInstallState:HelperToolInstallationState = .notInstalled
    private (set) var monitor: HelperToolMonitor
    private let sharedConstants:SharedConstant
    private var xpcClient: XPCClient
    init(){
        xpcClient = XPCClient.forMachService(named: "cn.magicdian.staticrouter.helper")
        self.helperInstallState = .notInstalled
        do{
            sharedConstants = try SharedConstant()
        }catch{
            fatalError("""
            One or more property list configuration issues exist. Please check the PropertyListModifier.swift script \
            is run as part of the build process for both the app and helper tool targets. This script will \
            automatically create all of the necessary configurations.
            Issue: \(error)
            """)
        }
        self.monitor = HelperToolMonitor(constants: sharedConstants)
        self.updateInstallationStatus(self.monitor.determineStatus())
    }
}

extension RouterCore {
    //MARK: XPC with Helper Functions
    func SendDebugCmd(){
        Task{
            try await xpcClient.send(to:SharedConstant.debugRoute)
        }
        print("Try send command message")
    }
    
    func SendUninstallCmd() {
        Task {
            try await xpcClient.send(to: SharedConstant.uninstallRoute)
        }
    }
    
    func ShowSystemRoute() {
        let command = RouterCommand.BuildPrintRouteCommand()
        Task {
            xpcClient.sendMessage(command,to: SharedConstant.commandRoute,withResponse: self.commandReply(_:))
        }
    }
    
    func ModifySystemRoute(_ addToRoute: Bool, _ network: String, _ netmask: String, _ gateway: String, _ gatewayType: RouterCommand.GatewayType){
        let command = RouterCommand.BuildManageRouteCommand(addToRoute: addToRoute, network: network, mask: netmask, gateway: gateway ,gatewayType: .interface)
        Task{
            xpcClient.sendMessage(command,to: SharedConstant.commandRoute,withResponse: self.commandReply(_:))
        }
    }
    
    func commandReply(_ result: Result<RouterCommandReply, XPCError>) {
        print("Command Reply!")
        DispatchQueue.main.async {
            switch result {
            case let .success(reply):
                print("command success \(String(describing: reply.standardOutput))")
                if let output = reply.standardOutput{
                    print("Command Reply output: \(output)")
                }
            case let .failure(error):
                print("Command Reply Error: \(error)")
            }
        }
    }
}


extension RouterCore {
    //MARK: Helper Tool Management Functions [Install/Uninstall/CheckState]
    /// Update the install state
    mutating func updateHelperInstallState(installed: HelperToolInstallationState){
        self.helperInstallState = installed
    }
    
    mutating func InstallHelper(InstallMessage:String){
        do {
            try PrivilegedHelperManager.shared
                .authorizeAndBless(message: InstallMessage ,icon: nil)
        } catch AuthorizationError.canceled {
            // No user feedback needed, user canceled
            print("User Canceled Installation")
            //            self.updateInstallationStatus(self.monitor.determineStatus(),completion: self.updateHelperInstallState(installed:))
        } catch {
            //Do something
        }
    }
    
    mutating func CheckInstallationState(){
        self.updateInstallationStatus(self.monitor.determineStatus())
    }
    mutating func CheckAndUpdateStatus(_ status:HelperToolInstallationState){
        if(self.helperInstallState != status){
            self.helperInstallState = status
        }else{
            print("Status not changed")
        }
    }
    
    mutating func updateInstallationStatus(_ status:HelperToolMonitor.InstallationStatus){
        if status.registeredWithLaunchd {
            if status.registrationPropertyListExists {
                //MARK: Registered: yes | Registration file: yes | Helper tool: yes
                if case .exists(let installedHelperToolVersion) = status.helperToolExecutable {
                    if installedHelperToolVersion < sharedConstants.helperToolVersion {
                        print("Helper need upgrade")
                        CheckAndUpdateStatus(.needUpgrade)
                    }else if installedHelperToolVersion == sharedConstants.helperToolVersion{
                        print("Helper installed")
                        CheckAndUpdateStatus(.installed)
                    }else{
                        print("Helper installed but not compatible")
                        CheckAndUpdateStatus(.notCompatible)
                    }
                    
                } else { //MARK: Registered: yes | Registration file: yes | Helper tool: no
                    print("NOT INSTALL! Helper tool missing")
                    CheckAndUpdateStatus(.notInstalled)
                }
            } else {
                //MARK: Registered: yes | Registration file: no | Helper tool: yes
                if case .exists(let installedHelperToolVersion) = status.helperToolExecutable {
                    print("NOT INSTALL! registration file missing VER:\(installedHelperToolVersion)")
                } else { // Registered: yes | Registration file: no | Helper tool: no
                    print("NOT INSTALL! helper tool and registration file missing")
                }
                CheckAndUpdateStatus(.notInstalled)
            }
        } else {
            if status.registrationPropertyListExists {
                //MARK: Registered: no | Registration file: yes | Helper tool: yes
                if case .exists(let installedHelperToolVersion) = status.helperToolExecutable {
                    print("NOT INSTALL! helper tool and registration file exist VER:\(installedHelperToolVersion)")
                } else { // Registered: no | Registration file: yes | Helper tool: no
                    print("NOT INSTALL! registration file exists")
                }
            } else {
                //MARK: Registered: no | Registration file: no | Helper tool: yes
                if case .exists(let installedHelperToolVersion) = status.helperToolExecutable {
                    print("NOT INSTALL! helper tool exists VER:\(installedHelperToolVersion)")
                } else { //MARK: Registered: no | Registration file: no | Helper tool: no
                    print("NOT INSTALL!")
                }
            }
            CheckAndUpdateStatus(.notInstalled)
        }
    }
}
