//
//  SelfUninstaller.swift
//  cn.magicdian.staticrouter.helper
//
//  Created by 经典 on 11/1/2023.
//

import Foundation
import Authorized

enum SelfUninstaller {
    enum UninstallError:Error {
        /// Uninstall will not be performed because this code is not running from the blessed location.
        case notRunningFromBlessedLocation(location: URL)
        /// Attempting to unload using `launchctl` failed.
        case launchctlFailure(statusCode: Int32)
        /// The argument provided must be a process identifier, but was not.
        case notProcessId(invalidArgument: String)
    }
    static let commandLineArgument = "uninstall"
    
    //MARK: TODO: ASK FOR AUTHORIZE TO UNINSTALL
    static func uninstall() throws {
        NSLog("StaticRouterHelper start to uninstall")
        let process = Process()
        process.launchPath = try CodeInfo.currentCodeLocation().path
        process.qualityOfService = QualityOfService.utility
        process.arguments = [commandLineArgument, String(getpid())]
        process.launch()
        NSLog("about to exit...")
        exit(0)
    }
    
    static func uninstallFromCommandLine(withArguments arguments:[String]) throws -> Never {
        if arguments.count == 1 {
            try uninstallImmediately()
        }else {
            guard let pid: pid_t = Int32(arguments[1]) else {
                throw UninstallError.notProcessId(invalidArgument: arguments[1])
            }
            try uninstallAfterProcessExits(pid: pid)
        }
    }
    
    static func uninstallAfterProcessExits(pid: pid_t) throws -> Never {
        // When passing 0 as the second argument, no signal is sent, but existence and permission checks are still
        // performed. This checks for the existence of a process ID. If 0 is returned the process still exists, so loop
        // until 0 is no longer returned.
        while kill(pid, 0) == 0 { // in practice this condition almost always evaluates to false on its first check
            usleep(50 * 1000) // sleep for 50ms
            NSLog("PID \(getpid()) waited 50ms for PID \(pid)")
        }
        NSLog("PID \(getpid()) done waiting for PID \(pid)")
        
        try uninstallImmediately()
    }
    
    //MARK: Real Uninstall Process
    static func uninstallImmediately() throws -> Never {
        let shareConst = try SharedConstant()
        let currentPath = try CodeInfo.currentCodeLocation()
        guard currentPath == shareConst.blessedLocation else {
            throw UninstallError.notRunningFromBlessedLocation(location: currentPath)
        }
        // Equivalent to: launchctl unload /Library/LaunchDaemons/<helper tool name>.plist
        let process = Process()
        process.launchPath = "/bin/launchctl"
        process.qualityOfService = QualityOfService.utility
        process.arguments = ["unload", shareConst.blessedPropertyListLocation.path]
        process.launch()
        NSLog("StaticRouterHelper about to wait for launchctl...")
        process.waitUntilExit()
        let terminationStatus = process.terminationStatus
        guard terminationStatus == 0 else {
            throw UninstallError.launchctlFailure(statusCode: terminationStatus)
        }
        NSLog("StaticRouterHelper unloaded from launchctl")
        
        // Equivalent to: rm /Library/LaunchDaemons/<helper tool name>.plist
        try FileManager.default.removeItem(at: shareConst.blessedPropertyListLocation)
        NSLog("StaticRouterHelper property list deleted")
        
        // Equivalent to: rm /Library/PrivilegedHelperTools/<helper tool name>
        try FileManager.default.removeItem(at: shareConst.blessedLocation)
        NSLog("StaticRouterHelper helper tool deleted")
        NSLog("StaticRouterHelper uninstall completed, exiting...")
        exit(0)
    }
    
}
