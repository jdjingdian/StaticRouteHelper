//
//  SelfUninstaller.swift
//  cn.magicdian.staticrouter.helper
//
//  Created by 经典 on 11/1/2023.
//

import Foundation
import Authorized
import OSLog

enum SelfUninstaller {
    private static let logger = Logger(subsystem: "cn.magicdian.staticrouter", category: "helper-uninstall")

    enum UninstallError:Error {
        /// Uninstall will not be performed because this code is not running from the blessed location.
        case notRunningFromBlessedLocation(location: URL)
        /// Attempting to unload using `launchctl` failed.
        case launchctlFailure(command: String, statusCode: Int32, output: String)
        /// The argument provided must be a process identifier, but was not.
        case notProcessId(invalidArgument: String)
    }
    static let commandLineArgument = "uninstall"
    
    //MARK: TODO: ASK FOR AUTHORIZE TO UNINSTALL
    static func uninstall() throws {
        logger.info("Received uninstall request via XPC (pid: \(getpid(), privacy: .public))")
        // Return from the XPC handler first so the client receives a reply,
        // then uninstall in this same process.
        // Spawning a child process can race with launchd teardown and the child
        // may be terminated before uninstall side effects complete.
        logger.info("Scheduling in-process deferred uninstall")
        DispatchQueue.global(qos: .utility).async {
            usleep(50 * 1000) // give reply channel a brief head start
            logger.info("Starting deferred in-process uninstall")
            do {
                try uninstallImmediately()
            } catch {
                logger.error("Deferred self-uninstall failed: \(error.localizedDescription, privacy: .public)")
                exit(1)
            }
        }
    }

    static func uninstallFromCommandLine(withArguments arguments:[String]) throws -> Never {
        logger.info("Running uninstall worker from command line (argsCount: \(arguments.count, privacy: .public))")
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
        logger.info("Waiting for parent process to exit (parentPid: \(pid, privacy: .public))")
        // When passing 0 as the second argument, no signal is sent, but existence and permission checks are still
        // performed. This checks for the existence of a process ID. If 0 is returned the process still exists, so loop
        // until 0 is no longer returned.
        var waitCycles = 0
        while kill(pid, 0) == 0 { // in practice this condition almost always evaluates to false on its first check
            usleep(50 * 1000) // sleep for 50ms
            waitCycles += 1
        }
        logger.info("Parent process exited (parentPid: \(pid, privacy: .public), waitedCycles: \(waitCycles, privacy: .public))")

        try uninstallImmediately()
    }
    
    //MARK: Real Uninstall Process
    static func uninstallImmediately() throws -> Never {
        let shareConst = try SharedConstant()
        let currentPath = try CodeInfo.currentCodeLocation()
        logger.info("Starting uninstallImmediately (currentPath: \(currentPath.path, privacy: .public), blessedPath: \(shareConst.blessedLocation.path, privacy: .public))")
        guard currentPath == shareConst.blessedLocation else {
            logger.error("Abort uninstall: helper not running from blessed location (currentPath: \(currentPath.path, privacy: .public))")
            throw UninstallError.notRunningFromBlessedLocation(location: currentPath)
        }

        // Equivalent to: rm /Library/LaunchDaemons/<helper tool name>.plist
        if FileManager.default.fileExists(atPath: shareConst.blessedPropertyListLocation.path) {
            try FileManager.default.removeItem(at: shareConst.blessedPropertyListLocation)
        }
        let plistExists = FileManager.default.fileExists(atPath: shareConst.blessedPropertyListLocation.path)
        logger.info("LaunchDaemon plist removed: \((!plistExists), privacy: .public)")
        
        // Equivalent to: rm /Library/PrivilegedHelperTools/<helper tool name>
        if FileManager.default.fileExists(atPath: shareConst.blessedLocation.path) {
            try FileManager.default.removeItem(at: shareConst.blessedLocation)
        }
        let helperExists = FileManager.default.fileExists(atPath: shareConst.blessedLocation.path)
        logger.info("Blessed helper binary removed: \((!helperExists), privacy: .public)")

        // Exit current daemon process; without launchd plist/binary, it cannot be relaunched.
        logger.info("Self-uninstall completed; exiting helper process")
        exit(0)
    }
    
}
