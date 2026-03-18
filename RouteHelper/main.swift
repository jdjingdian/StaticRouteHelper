//
//  main.swift
//  RouterHelper
//
//  Created by 经典 on 9/1/2023.
//

import Foundation
import SecureXPC
import OSLog

let helperLogger = Logger(subsystem: "cn.magicdian.staticrouter", category: "helper-main")

let ppid = getppid()
helperLogger.info("Helper process started (pid: \(getpid(), privacy: .public), ppid: \(ppid, privacy: .public))")

if CommandLine.arguments.count > 1 {
    // Remove the first argument, which represents the name (typically the full path) of this helper tool
    var arguments = CommandLine.arguments
    _ = arguments.removeFirst()
    helperLogger.info("Helper launched with command arguments (count: \(arguments.count, privacy: .public))")

    if let firstArgument = arguments.first {
        if firstArgument == SelfUninstaller.commandLineArgument {
            do {
                try SelfUninstaller.uninstallFromCommandLine(withArguments: arguments)
            } catch {
                helperLogger.error("Uninstall command failed: \(error.localizedDescription, privacy: .public)")
                exit(1)
            }
        } else {
            helperLogger.warning("Unknown helper argument: \(firstArgument, privacy: .public)")
        }
    }
}else if(ppid == 1){
    helperLogger.info("Helper started by launchd, starting XPC server")
    let server = try XPCServer.forMachService()
    server.registerRoute(SharedConstant.debugRoute, handler: ProcessRunner.run_whoami)
    helperLogger.info("Registered helper debug route")
//    server.registerRoute(SharedConstant.uninstallRoute, handler: SelfUninstaller.uninstall)
    server.registerRoute(SharedConstant.uninstallRoute, handler: SelfUninstaller.uninstall)
    server.registerRoute(SharedConstant.commandRoute, handler: PFRouteWriter.write(request:))

    helperLogger.info("Registered helper uninstall and command routes")
    ///
    server.setErrorHandler { error in
        if case .connectionInvalid = error {
            // Ignore invalidated connections as this happens whenever the client disconnects which is not a problem
        } else {
            helperLogger.error("Helper XPC server error: \(error.localizedDescription, privacy: .public)")
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
