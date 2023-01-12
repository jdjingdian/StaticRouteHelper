//
//  main.swift
//  RouterHelper
//
//  Created by 经典 on 9/1/2023.
//

import Foundation
import SecureXPC


let ppid = getppid()
NSLog("StaticRouterHelper Started By: \(ppid)")

if CommandLine.arguments.count > 1 {
    // Remove the first argument, which represents the name (typically the full path) of this helper tool
    var arguments = CommandLine.arguments
    _ = arguments.removeFirst()
    NSLog("StaticRouterHelper run with arguments: \(arguments)")

    if let firstArgument = arguments.first {
        if firstArgument == SelfUninstaller.commandLineArgument {
            try SelfUninstaller.uninstallFromCommandLine(withArguments: arguments)
        } else {
            NSLog("StaticRouterHelper argument not recognized: \(firstArgument)")
        }
    }
}else if(ppid == 1){
    NSLog("StaticRouterHelper Started By Launchd, Starting Server")
    let server = try XPCServer.forMachService()
    server.registerRoute(SharedConstant.debugRoute, handler: ProcessRunner.run_whoami)
    NSLog("StaticRouterHelper set debugRoute Complete")
//    server.registerRoute(SharedConstant.uninstallRoute, handler: SelfUninstaller.uninstall)
    server.registerRoute(SharedConstant.uninstallRoute, handler: SelfUninstaller.uninstall)
    server.registerRoute(SharedConstant.commandRoute, handler: ProcessRunner.runCommand(wrapCmd:))
    
    NSLog("StaticRouterHelper set uninstallRoute Complete")
    ///
    server.setErrorHandler { error in
        if case .connectionInvalid = error {
            // Ignore invalidated connections as this happens whenever the client disconnects which is not a problem
        } else {
            NSLog("StaticRouterHelper error: \(error)")
        }
    }
    //MARK: Start server and not quit
    server.startAndBlock()
}else{
    print("Usage: \(try CodeInfo.currentCodeLocation().lastPathComponent) <command>")
    print("\nCommands:")
    print("\t\(SelfUninstaller.commandLineArgument)\tUnloads and deletes from disk this helper tool and configuration.")
    exit(0)
}
