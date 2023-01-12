//
//  ProcessRunner.swift
//  cn.magicdian.staticrouter.helper
//
//  Created by 经典 on 11/1/2023.
//

import Foundation
import Authorized

enum ProcessRunner {
    
    static func run_whoami() {
        // Prompt user to authorize if the client requested it
        let task = Process()
        let pipe = Pipe()
        task.launchPath = "/usr/bin/whoami"
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let string = String(data: data, encoding: String.Encoding.utf8) {
            NSLog("StaticRouterHelper whoami : "+string)
        }
    }
    
    static func runCommand(wrapCmd: RouterCommand) throws -> RouterCommandReply {
        NSLog("StaticRouterHelper run router command")
        let process = Process()
        NSLog("StaticRouterHelper DBG command launchPath \(wrapCmd.commandType.launchPath)")
        NSLog("StaticRouterHelper DBG command argument \(wrapCmd.commandArgs)")
        process.launchPath = wrapCmd.commandType.launchPath
        process.arguments = wrapCmd.commandArgs
        process.qualityOfService = QualityOfService.userInitiated
        let outputPipe = Pipe()
        defer { outputPipe.fileHandleForReading.closeFile() }
        process.standardOutput = outputPipe
        let errorPipe = Pipe()
        defer { errorPipe.fileHandleForReading.closeFile() }
        process.standardError = errorPipe
        process.launch()
        process.waitUntilExit()

        // Convert a pipe's data to a string if there was non-whitespace output
        let pipeAsString = { (pipe: Pipe) -> String? in
            let output = String(data: pipe.fileHandleForReading.availableData, encoding: String.Encoding.utf8)?
                            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return output.isEmpty ? nil : output
        }
        
        let outputMsg = pipeAsString(outputPipe)
        let errorMsg = pipeAsString(errorPipe)
        return RouterCommandReply(terminationStatus: process.terminationStatus, standardOutput: outputMsg, standardError: errorMsg)
    }
}
