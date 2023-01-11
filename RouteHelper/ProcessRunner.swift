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
}
