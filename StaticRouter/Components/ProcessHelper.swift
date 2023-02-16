//
//  ProcessHelper.swift
//  StaticRouteHelper
//
//  Created by Derek Jing on 2021/10/27.
//

import Foundation
import Cocoa

//MARK: Deprecated
class ProcessHelper:ObservableObject {
    @Published var netstat: String = ""
    @Published var netArray: [netData] = []
    func manualRoute(isAdd:Bool,password:String,args:[String]){
        if isAdd == true{
            let taskOne = Process()
            taskOne.launchPath = "/bin/echo"
            taskOne.arguments = [password]
            
            let taskTwo = Process()
            taskTwo.launchPath = "/usr/bin/sudo"
//            taskTwo.arguments = ["-S", "/sbin/route","-n","add","-net",network,"-netmask",mask,gateway]
            taskTwo.arguments = args
            let pipeBetween:Pipe = Pipe()
            taskOne.standardOutput = pipeBetween
            taskTwo.standardInput = pipeBetween
            
            let pipeToMe = Pipe()
            taskTwo.standardOutput = pipeToMe
            taskTwo.standardError = pipeToMe
            taskOne.launch()
            taskTwo.launch()
            let data = pipeToMe.fileHandleForReading.readDataToEndOfFile()
//            let output : String = NSString(data: data, encoding: String.Encoding.utf8.rawValue) as! String
            let output:String = String(data: data, encoding: .utf8)!
            print(output)
        }else{
            let taskOne = Process()
            taskOne.launchPath = "/bin/echo"
            taskOne.arguments = [password]
            
            let taskTwo = Process()
            taskTwo.launchPath = "/usr/bin/sudo"
//            taskTwo.arguments = ["-S", "/sbin/route","delete","-net",network,"-gateway",gateway]
            taskTwo.arguments = args
            let pipeBetween:Pipe = Pipe()
            taskOne.standardOutput = pipeBetween
            taskTwo.standardInput = pipeBetween
            
            let pipeToMe = Pipe()
            taskTwo.standardOutput = pipeToMe
            taskTwo.standardError = pipeToMe
            
            taskOne.launch()
            taskTwo.launch()
        }
        
    }
    
    func checkRoute(){
        self.netArray = []
        var count = 0
        let task = Process()
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        let args = ["-nr","-f","inet","|","column","-t","-w","25","-c","2"]
        task.arguments = args
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/netstat")
        task.terminationHandler = { _ in
            print("process run complete.")
        }
        do {
            try task.run()
        }catch{
            print("netstat run error")
        }
        do{
            let data = try pipe.fileHandleForReading.readToEnd()
            if !data!.isEmpty{
                let outputString = String(data: data!, encoding: .utf8)!
                let splitString = outputString[outputString.index(outputString.startIndex, offsetBy: 93)..<outputString.endIndex]
                //                print(splitString)
                let splitLine = splitString.split(whereSeparator: \.isNewline)
                for line in splitLine {
                    let splitType = line.split(separator:" ")
                    if splitType.count == 5{
                        let dataLine:netData = netData(index: count, gateway: String(splitType[1]), destination: String(splitType[0]), flags: String(splitType[2]), interface: String(splitType[3]),expire:String(splitType[4]))
                        self.netArray.append(dataLine)
                        
                    }
                    else{
                        let dataLine = netData(index: count, gateway: String(splitType[1]), destination: String(splitType[0]), flags: String(splitType[2]), interface: String(splitType[3]),expire: "STATIC")
                        self.netArray.append(dataLine)
                    }
                    
                    count += 1;
                }
                //                print(splitLine)
                DispatchQueue.main.async {
                    self.netstat = String(splitString)
                    //                    print("netstat:\(self.netstat)")
                }
            }
            
        }catch{
            print("read netstat error")
        }
        
        
    }
}
class SuHelper:ObservableObject {
    @Published var truePass:Bool = false
    func checkPass(password: String) {
        let task = Process()
        let taskEcho = Process()
        taskEcho.executableURL = URL(fileURLWithPath: "/bin/echo")
        taskEcho.arguments = [password]
        var environment =  ProcessInfo.processInfo.environment
        environment["PATH"] = "/usr/bin/"
        task.environment = environment
        
        task.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        let args = ["-S","-k","whoami"]
        task.arguments = args
        //use pipe to get the execution program's output
        let pipeInside = Pipe()
        let pipeOutside = Pipe()
        taskEcho.standardOutput = pipeInside
        task.standardInput = pipeInside
        task.standardOutput = pipeOutside
        task.standardError = pipeOutside
        task.currentDirectoryURL = URL(fileURLWithPath: NSString(string:"~/").expandingTildeInPath)
        taskEcho.currentDirectoryURL = URL(fileURLWithPath: NSString(string:"~/").expandingTildeInPath)
        do{
            try taskEcho.run()
            try task.run()
        }catch{
            print("发生错误")
        }
        do{
            let data = try pipeOutside.fileHandleForReading.readToEnd()
            if data != nil {
                let outputStr = String(data: data!, encoding: .utf8)!
                DispatchQueue.main.async {
                    if outputStr.contains("Sorry"){
                        print("Wrong Password")
                        self.truePass = false
                    }else{
                        print("True Password")
                        self.truePass = true
                    }
                }
                print("Output:\(outputStr)")
                print("isTruePass:\(truePass)")
                
            }
        }catch{
            print("Read Error")
        }
        
    }
}

